module Tap
  module Support
    
    # == Syntax
    #
    # ==== Round Assignment
    # Tasks can be defined and set to a round using the following:
    #
    #   break           assigns task(s)         to round
    #   --              next                    0
    #   --+             next                    1
    #   --++            next                    2
    #   --+2            next                    2
    #   --+2[1,2,3]     1,2,3                   2
    #
    # Here all task (except c) are parsed into round 0, then the
    # final argument reassigns e to round 3.
    #
    #   schema = Parser.new("a -- b --+ c -- d -- e --+3[4]").schema
    #   a, b, c, d, e = schema.nodes
    #   schema.rounds                   # => [[a,b,d],[c], nil, [e]]
    #
    # ==== Workflow Assignment
    # All simple workflow patterns except switch can be specified within
    # the parse syntax (switch is the exception because there is no good
    # way to define the switch block).  
    #
    #   break      pattern       source(s)      target(s)
    #   --:        sequence      last           next
    #   --[]       fork          last           next
    #   --{}       merge         next           last
    #   --()       sync_merge    next           last
    #
    #   example       meaning
    #   --1:2         1.sequence(2)
    #   --1:2:3       1.sequence(2,3)
    #   --:2:         last.sequence(2,next)
    #   --[]          last.fork(next)
    #   --1{2,3,4}    1.merge(2,3,4)
    #   --(2,3,4)     last.sync_merge(2,3,4)
    #
    # Note how all of the bracketed styles behave similarly; they are
    # parsed with essentially the same code, but reverse the source
    # and target in the case of merges.
    #
    # Here a and b are sequenced inline.  Task c is assigned to no 
    # workflow until the final argument which sequenced b and c.
    #
    #   schema = Parser.new("a --: b -- c --1:2i").schema
    #   a, b, c = schema.nodes
    #   schema.joins.collect .collect do |join_type, inputs, outputs, modifier|
    #     [join_type, inputs, outputs, modifier]
    #   end
    #   # => [['join',[a],[b],""], ["join",[b],[c],"i"]]
    #
    # ==== Globals
    # Global prerequisites of task (used, for example, by dependencies) may
    # be assigned in the parse syntax as well.  The break for a global
    # is '--*'.
    #
    #   schema = Parser.new("a -- b --* c").schema
    #   a, b, c = schema.nodes
    #   schema.globals                  # => [c]
    #
    # ==== Escapes and End Flags
    # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
    # any number of arguments may be enclosed within the escape. After the 
    # end delimiter, breaks are active once again.
    #
    #   schema = Parser.new("a -- b -- c").schema
    #   schema.argvs                    # => [["a"], ["b"], ["c"]]
    # 
    #   schema = Parser.new("a -. -- b .- -- c").schema
    #   schema.argvs                    # => [["a", "--", "b"], ["c"]]
    #
    # Parsing continues until the end of argv, or a an end flag '---' is 
    # reached.  The end flag may also be escaped.
    #
    #   schema = Parser.new("a -- b --- c").schema
    #   schema.argvs                    # => [["a"], ["b"]]
    #
    class Parser
      
      # A set of parsing routines used internally by Tap::Support::Parser,
      # modularized for ease of testing, and potential re-use. These methods 
      # require that <tt>current_index</tt> and <tt>previous_index</tt> be 
      # implemented in the including class.
      module Utils
        module_function

        # The escape begin argument
        ESCAPE_BEGIN = "-."

        # The escape end argument
        ESCAPE_END = ".-"

        # The parser end flag
        END_FLAG = "---"

        # Matches any breaking arg. Examples:
        #
        #   --
        #   --+
        #   --1:2
        #   --[1][2]
        #   --[1,2,3][4,5,6]is.join
        #
        # After the match:
        #
        #   $1:: The string after the break
        #        (ex: '--' => '', '--++' => '++', '--[1,2][3,4]is.join' => '[1,2][3,4]is.join')
        #
        BREAK =  /\A--(\z|[\+\d\:\*\[].*\z)/

        # Matches an execution-round break. Examples:
        #
        #   +
        #   ++
        #   +1
        #   +1[1,2,3]
        #
        # After the match:
        #
        #   $1:: The round string, or nil.
        #        (ex: '++' => '++', '+1' => '+1')
        #   $2:: The target string, or nil. 
        #        (ex: '+' => nil, '+[1,2,3]' => '1,2,3')
        #
        ROUND = /\A(\+(?:\d*|\+*))(?:\[([\d,]*)\])?\z/

        # Matches a sequence break. Examples:
        #
        #   :
        #   1:
        #   :2
        #   1:2:3
        #
        # After the match:
        #
        #   $1:: The sequence string after the break. 
        #        (ex: ':' => ':', '1:2' => '1:2', '1:' => '1:', ':2' => ':2')
        #   $2:: The modifier string.
        #        (ex: ':i' => 'i', '1:2is' => 'is')
        #
        SEQUENCE = /\A(\d*(?::\d*)+)([A-z]*)\z/

        # Matches an prerequisite break. Examples:
        #
        #   *
        #   *[1,2,3]
        #
        # After the match:
        #
        #   $1:: The index string after the break.
        #        (ex: '*' => nil, '*[1,2,3]' => '1,2,3')
        #
        PREREQUISITE = /\A\*(?:\[([\d,]*)\])?\z/
        
        # Matches a generic join break. Examples:
        #
        #   [1,2,3][4,5,6]is.join
        #   [1,2][3,4]
        #   [1][2]
        #
        # After the match:
        #
        #   $1:: The inputs string.
        #        (ex: '[1,2,3][4,5,6]' => '1,2,3')
        #   $2:: The outputs string.
        #        (ex: '[1,2,3][4,5,6]' => '4,5,6')
        #   $3:: The modifier string.
        #        (ex: '[][]is' => 'is')
        #   $4:: The join type, if present.
        #        (ex: '.join[][]' => 'join', '.[][]' => '', '[][]' => nil)
        #
        JOIN = /\A\[([\d,]*)\]\[([\d,]*)\]([A-z]*)(?:.(\w*[\w:]*))?\z/
        
        # Parses an indicies str along commas, and collects the indicies
        # as integers. Ex:
        #
        #   parse_indicies('')                  # => []
        #   parse_indicies('1')                 # => [1]
        #   parse_indicies('1,2,3')             # => [1,2,3]
        #
        def parse_indicies(str, regexp=/,+/)
          indicies = []
          str.split(regexp).each do |n|
            indicies << n.to_i unless n.empty?
          end
          indicies
        end

        # Parses the match of a ROUND regexp into a round index and an array
        # of task indicies that should be added to the round. The inputs
        # correspond to $1 and $2 for the match.
        #
        # If $2 is empty then indicies of [:current_index] are assumed.
        #
        #   parse_round("+", "")                # => [1, [:current_index]]
        #   parse_round("+2", "1,2,3")          # => [2, [1,2,3]]
        #
        def parse_round(one, two)
          index = case one
          when /\d/ then one[1, one.length-1].to_i
          else one.length
          end
          [index, two && !two.empty? ? parse_indicies(two): [current_index]]
        end

        # Parses the match of a SEQUENCE regexp an array of [join_type,
        # input_indicies, output_indicies, modifiers] arrays. The inputs
        # corresponds to $1 and $2 for the match. The previous and current
        # index are assumed if $1 starts and/or ends with a semi-colon.
        #
        #   parse_sequence("1:2:3", '')
        #   # => [
        #   # ['join', [1], [2], ""],
        #   # ['join', [2], [3], ""]
        #   # ]
        #
        #   parse_sequence(":1:2:", '')
        #   # => [
        #   # ['join', [:previous_index], [1], ""],
        #   # ['join', [1], [2], ""],
        #   # ['join', [2], [:current_index], ""],
        #   # ]
        #
        def parse_sequence(one, two)
          indicies = parse_indicies(one, /:+/)
          indicies.unshift previous_index if one[0] == ?:
          indicies << current_index if one[-1] == ?:
          
          sequences = []
          while indicies.length > 1
            sequences << [[indicies.shift], [indicies[0]], {:argv => ['join', two]}]
          end
          sequences
        end

        # Parses the match of an PREREQUISITE regexp into an [indicies] array.
        # The input corresponds to $1 for the match. If $1 is empty then 
        # indicies of [:current_index] are assumed.
        #
        #   parse_prerequisite("1")             # => [1]
        #   parse_prerequisite("")              # => [:current_index]
        #
        def parse_prerequisite(one)
          one && !one.empty? ? parse_indicies(one) : [current_index]
        end

        # Parses the match of a JOIN regexp into a [join_type, input_indicies,
        # output_indicies, modifiers] array. The inputs corresponds to $1,
        # $2, $3, and $4 for a match to a JOIN regexp. A join type of 
        # 'join' is assumed unless otherwise specified.
        #
        #   parse_join("1", "2,3", "", "")      # => ['join', [1], [2,3], ""]
        #   parse_join("", "", "is", "type")    # => ['type', [], [], "is"]
        #
        def parse_join(one, two, three, four)
          inputs = parse_indicies(one)
          outputs = parse_indicies(two)
          join_type = four && !four.empty? ? four : 'join'
          [inputs, outputs, {:argv => [join_type, three]}]
        end
      end
      
      include Utils
      
      # The schema into which nodes are parsed
      attr_reader :schema
      
      def initialize(argv=[])
        parse(argv)
      end

      # Iterates through the argv splitting out task and workflow definitions.
      # Task definitions are split out (with configurations) along round and/or
      # workflow break lines.  Rounds and workflows are dynamically parsed;
      # tasks may be reassigned to different rounds or workflows by later 
      # arguments.
      #
      # Parse is non-destructive to argv.  If a string argv is provided, parse
      # splits it into an array using Shellwords; if a hash argv is provided,
      # parse converts it to an array using Parser::Utils#parse_argh.
      #
      def parse(argv)
        parse!(argv.kind_of?(String) ? argv : argv.dup)
      end

      # Same as parse, but removes parsed args from argv.
      def parse!(argv)
        @current_index = 0
        @schema = Schema.new
        
        # prevent the addition of an empty node to schema
        return if argv.empty?
        
        argv = Shellwords.shellwords(argv) if argv.kind_of?(String)
        argv.unshift('--')
        
        escape = false
        current_argv = nil
        while !argv.empty?
          arg = argv.shift

          # if escaping, add escaped arguments 
          # until an escape-end argument
          if escape
            if arg == ESCAPE_END
              escape = false
            else
              (current_argv ||= argv(current_index)) << arg
            end

            next
          end
          
          case arg
          when ESCAPE_BEGIN
            # begin escaping if indicated
            escape = true
            
          when END_FLAG
            # break on an end-flag
            break
          
          when BREAK
            # a breaking argument was reached:
            # unless the current argv is empty,
            # append and start a new definition
            if current_argv && !current_argv.empty?
              self.current_index += 1
              current_argv = nil
            end
            
            # parse the break string for any
            # schema modifications
            parse_break($1)
            
          else
            # add all other non-breaking args to
            # the current argv; this includes
            # both inputs and configurations
            (current_argv ||= argv(current_index)) << arg
            
          end
        end
        
        schema
      end
      
      def load(argv)
        argv.each do |args|
          case args
          when Hash
            case
            when args.has_key?('round')
              schema.set_round(args['round'], args['indicies'])
            when args.has_key?('join')
              schema.set_join(args['join'], args['inputs'], args['outputs'])#, args['config'])
            when args.has_key?('prerequisite')
              args['prerequisite'].each {|index| schema[index].make_prerequisite }
            else
              schema.nodes << Node.new(args)
              self.current_index += 1
            end
          when Array
            schema.nodes << Node.new(args)
            self.current_index += 1
          when String
            args.split(/\s/).each do |arg|
              parse_break(arg)
            end
          when nil
          else
            raise "invalid arg: #{args}"
          end
        end
        
        # cleanup is currently required if terminal joins like
        # --0[] are allowed (since it's interpreted as --0[next])
        schema.cleanup
      end
      
      protected
      
      # The index of the node currently being parsed.
      attr_accessor :current_index # :nodoc:
      
      def argv(index)
        schema[index].argh[:argv] ||= []
      end
      
      # Returns current_index-1, or raises an error if current_index < 1.
      def previous_index # :nodoc:
        raise ArgumentError, 'there is no previous index' if current_index < 1
        current_index - 1
      end
      
      # determines the type of break and modifies self appropriately
      def parse_break(arg) # :nodoc:
        case arg
        when ""
          schema[current_index].round = 0
        when ROUND
          schema.set_round(*parse_round($1, $2))
        when SEQUENCE     
          parse_sequence($1, $2).each {|join| schema.set_join(*join) }
        when JOIN         
          schema.set_join(*parse_join($1, $2, $3, $4))
        when PREREQUISITE 
          schema.set_prerequisites(parse_prerequisite($1))
        else
          raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
    end
  end
end