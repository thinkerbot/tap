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
    # Global instances of task (used, for example, by dependencies) may
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

        # Defines a break regexp that matches a bracketed-pairs
        # break.  The left and right brackets are specified as
        # inputs.  After a match:
        #
        #   $1:: The source string after the break. 
        #        (ex: '[]' => '', '1[]' => '1')
        #   $2:: The target string. 
        #        (ex: '[]' => '', '1[1,2,3]' => '1,2,3')
        #   $3:: The modifier string.
        #        (ex: '[]i' => 'i', '1[1,2,3]is' => 'is')
        #
        def bracket_regexp(l, r)
          /\A(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}([A-z]*)\z/
        end

        # The escape begin argument
        ESCAPE_BEGIN = "-."

        # The escape end argument
        ESCAPE_END = ".-"

        # The parser end flag
        END_FLAG = "---"

        # Matches any breaking arg (ex: '--', '--+', '--1:2')
        # After the match:
        #
        #   $1:: The string after the break
        #        (ex: '--' => '', '--++' => '++', '--1(2,3)' => '1(2,3)')
        #
        BREAK =  /\A--(\z|[\+\d\:\*\[\{\(].*\z)/

        # Matches an execution-round break.  After the match:
        #
        #   $2:: The round string, or nil.
        #        (ex: '' => nil, '++' => '++', '+1' => '+1')
        #   $5:: The target string, or nil. 
        #        (ex: '+' => nil, '+[1,2,3]' => '1,2,3')
        #
        ROUND = /\A((\+(\d*|\+*))(\[([\d,]*)\])?)?\z/

        # Matches a sequence break.  After the match:
        #
        #   $1:: The sequence string after the break. 
        #        (ex: ':' => ':', '1:2' => '1:2', '1:' => '1:', ':2' => ':2')
        #   $3:: The modifier string.
        #        (ex: ':i' => 'i', '1:2is' => 'is')
        #
        SEQUENCE = /\A(\d*(:\d*)+)([A-z]*)\z/

        # Matches an instance break.  After the match:
        #
        #   $1:: The index string after the break.
        #        (ex: '*' => '', '*1' => '1')
        #
        INSTANCE = /\A\*(\d*)\z/

        # A break regexp using "[]"
        FORK = bracket_regexp("[", "]")

        # A break regexp using "{}"
        MERGE = bracket_regexp("{", "}")

        # A break regexp using "()"
        SYNC_MERGE = bracket_regexp("(", ")")

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
        # correspond to $2 and $5 for the match.
        #
        # If $2 is nil, a round index of zero is assumed; if $5 is nil or
        # empty, then indicies of [:current_index] are assumed.
        #
        #   parse_round("+", "")                # => [1, [:current_index]]
        #   parse_round("+2", "1,2,3")          # => [2, [1,2,3]]
        #   parse_round(nil, nil)               # => [0, [:current_index]]
        #
        def parse_round(two, five)
          index = case two
          when nil then 0
          when /\d/ then two[1, two.length-1].to_i
          else two.length
          end
          [index, five.to_s.empty? ? [current_index] : parse_indicies(five)]
        end

        # Parses the match of a SEQUENCE regexp into an [indicies, options] 
        # array. The inputs corresponds to $1 and $3 for the match. The 
        # previous and current index are assumed if $1 starts and/or ends 
        # with a semi-colon.
        #
        #   parse_sequence("1:2:3", '')         # => [[1,2,3], {}]
        #   parse_sequence(":1:2:", '')         # => [[:previous_index,1,2,:current_index], {}]
        #
        def parse_sequence(one, three)
          seq = parse_indicies(one, /:+/)
          seq.unshift previous_index if one[0] == ?:
          seq << current_index if one[-1] == ?:
          [seq, parse_options(three)]
        end

        # Parses the match of an INSTANCE regexp into an index.
        # The input corresponds to $1 for the match. The current
        # index is assumed if $1 is empty.
        #
        #   parse_instance("1")                 # => 1
        #   parse_instance("")                  # => :current_index
        #
        def parse_instance(one)
          one.empty? ? current_index : one.to_i
        end

        # Parses the match of an bracket_regexp into a [input_indicies,
        # output_indicies, options] array. The inputs corresponds to $1,
        # $2, and $3 for a match to a bracket regexp. The previous and
        # current index are assumed if $1 and/or $2 is empty.
        #
        #   parse_bracket("1", "2,3", "")       # => [[1], [2,3], {}]
        #   parse_bracket("", "", "")           # => [[:previous_index], [:current_index], {}]
        #   parse_bracket("1", "", "")          # => [[1], [:current_index], {}]
        #   parse_bracket("", "2,3", "")        # => [[:previous_index], [2,3], {}]
        #
        def parse_bracket(one, two, three)
          targets = parse_indicies(two)
          targets << current_index if targets.empty?
          [[one.empty? ? previous_index : one.to_i], targets, parse_options(three)]
        end
        
        # Same as parse_bracket but reverses the input and output indicies.
        def parse_reverse_bracket(one, two, three)
          inputs, outputs, options = parse_bracket(one, two, three)
          [outputs, inputs, options]
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
        
        # Parses an arg hash into a schema argv.  An arg hash is a hash
        # using numeric keys to specify the [row][col] in a two-dimensional
        # array where a set of values should go.  Breaks are added between
        # rows (if necessary) and the array is collapsed to yield the
        # argv:
        #
        #   argh = {
        #     0 => {
        #       0 => 'a',
        #       1 => ['b', 'c']},
        #     1 => 'z'
        #   }
        #   parse_argh(argh)    # => ['--', 'a', 'b', 'c', '--', 'z']
        # 
        # Non-numeric keys are converted to integers using to_i and
        # existing breaks (such as workflow breaks) occuring at the
        # start of a row are preseved.
        #
        #   argh = {
        #     '0' => {
        #       '0' => 'a',
        #       '1' => ['b', 'c']},
        #     '1' => ['--:', 'z']
        #   }
        #   parse_argh(argh)    # => ['--', 'a', 'b', 'c', '--:', 'z']
        #
        def parse_argh(argh)
          rows = []
          argh.each_pair do |row, values|
            if values.kind_of?(Hash)
              arry =  []
              values.each_pair {|col, value| arry[col.to_i] = value }
              values = arry
            end

            rows[row.to_i] = values
          end
          
          argv = []
          rows.each do |row|
            row = [row].flatten.compact
            if row.empty? || row[0] !~ BREAK
              argv << '--'
            end
            argv.concat row
          end
          argv
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
        
        argv = case argv
        when Array then argv
        when String then Shellwords.shellwords(argv) 
        when Hash then parse_argh(argv)
        else argv
        end
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
        when ROUND
          round, indicies = parse_round($2, $5)
          indicies.each {|index| schema[index].round = round }
          
        when SEQUENCE
          indicies, options = parse_sequence($1, $3)
          while indicies.length > 1
            schema.set(Join, [indicies.shift], [indicies[0]], options)
          end

        when INSTANCE    then schema[parse_instance($1)].globalize
        when FORK        then schema.set(Join, *parse_bracket($1, $2, $3))
        when MERGE       then schema.set(Join, *parse_reverse_bracket($1, $2, $3))
        when SYNC_MERGE  then schema.set(Joins::SyncMerge, *parse_reverse_bracket($1, $2, $3))
        else raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
    end
  end
end