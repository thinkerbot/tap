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
    #   schema.joins.collect do |join, inputs, outputs|
    #     [join.options, inputs, outputs]
    #   end                             # => [[{},[a],[b]], [{:iterate => true},[b],[c]]]
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
        #   --.join[1,2,3][4,5,6]
        #
        # After the match:
        #
        #   $1:: The string after the break
        #        (ex: '--' => '', '--++' => '++', '--.join[1,2][3,4]' => '.join[1,2][3,4]')
        #
        BREAK =  /\A--(\z|[\+\d\:\*\.\[].*\z)/

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
        #   .join[1,2,3][4,5,6]is
        #   .[1,2][3,4]
        #   [1][2]
        #
        # After the match:
        #
        #   $1:: The join type, if present.
        #        (ex: '.join[][]' => 'join', '.[][]' => '', '[][]' => nil)
        #   $2:: The inputs string.
        #        (ex: '[1,2,3][4,5,6]' => '1,2,3')
        #   $3:: The outputs string.
        #        (ex: '[1,2,3][4,5,6]' => '4,5,6')
        #   $4:: The modifier string.
        #        (ex: '[][]is' => 'is')
        #
        JOIN = /\A(?:.(\w*[\w:]*))?\[([\d,]*)\]\[([\d,]*)\]([A-z]*)\z/
        
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

        # Parses the match of a SEQUENCE regexp into an [indicies, options] 
        # array. The inputs corresponds to $1 and $2 for the match. The 
        # previous and current index are assumed if $1 starts and/or ends 
        # with a semi-colon.
        #
        #   parse_sequence("1:2:3", '')         # => [[1,2,3], {}]
        #   parse_sequence(":1:2:", '')         # => [[:previous_index,1,2,:current_index], {}]
        #
        def parse_sequence(one, two)
          seq = parse_indicies(one, /:+/)
          seq.unshift previous_index if one[0] == ?:
          seq << current_index if one[-1] == ?:
          [seq, parse_options(two)]
        end

        # Parses the match of an PREREQUISITE regexp into an [indicies] array.
        # The input corresponds to $1 for the match. If $1 is empty then 
        # indicies of [:current_index] are assumed.
        #
        #   parse_prerequisite("1")                 # => [1]
        #   parse_prerequisite("")                  # => [:current_index]
        #
        def parse_prerequisite(one)
          one && !one.empty? ? parse_indicies(one) : [current_index]
        end

        # Parses the match of a JOIN regexp into a [type, input_indicies,
        # output_indicies, options] array. The inputs corresponds to $1,
        # $2, $3, and $4 for a match to a JOIN regexp. The previous and
        # current index are assumed if $2 and/or $3 is empty.
        #
        #   parse_join(nil, "1", "2,3", "")       # => ['join', [1], [2,3], {}]
        #
        def parse_join(one, two, three, four)
          join = Join #one && !one.empty? ? one : Join
          inputs = parse_indicies(two)
          outputs = parse_indicies(three)
          [join, inputs, outputs, parse_options(four)]
        end
         
        # Parses an options string into a hash.  The input corresponds
        # to $3 in a SEQUENCE or bracket_regexp match.  Raises an error
        # if the options string contains unknown options.
        #
        #   parse_options("")                   # => {}
        #   parse_options("ik")                 # => {:iterate => true, :stack => true}
        #
        def parse_options(three)
          options = {}
          0.upto(three.length - 1) do |char_index|
            char = three[char_index, 1]
            
            entry = Join.configurations.find do |key, config| 
              config.attributes[:short] == char
            end
            key, config = entry
            
            raise "unknown option in: #{three} (#{char})" unless key 
            options[key] = true
          end
          options
        end
      end
      
      include Utils
      
      # The schema into which nodes are parsed
      attr_reader :schema
      
      def initialize(argv=[])
        @current_index = 0
        @schema = Schema.new
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
              (current_argv ||= schema[current_index].argv) << arg
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
            (current_argv ||= schema[current_index].argv) << arg
            
          end
        end
        
        schema
      end
      
      def load(argv)
        argv.each do |args|
          case args
          when Array
            schema.nodes << Node.new(args, 0)
            self.current_index += 1
          else
            parse_break(args)
          end
        end
        
        # cleanup is currently required if terminal joins like
        # --0[] are allowed (since it's interpreted as --0[next])
        schema.cleanup
      end
      
      protected
      
      # The index of the node currently being parsed.
      attr_accessor :current_index # :nodoc:
      
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
          round, indicies = parse_round($1, $2)
          indicies.each {|index| schema[index].round = round }
          
        when SEQUENCE
          indicies, options = parse_sequence($1, $2)
          while indicies.length > 1
            schema.set(Join, [indicies.shift], [indicies[0]], options)
          end
          
        when JOIN            then schema.set(*parse_join($1,$2,$3,$4))
        when PREREQUISITE    then parse_prerequisite($1).each {|index| schema[index].globalize }
        else raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
    end
  end
end