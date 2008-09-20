require 'tap/support/schema'
autoload(:Shellwords, 'shellwords')

module Tap
  module Support
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
        #        (ex: '--[]' => '', '--1[]' => '1')
        #   $2:: The target string. 
        #        (ex: '--[]' => '', '--1[1,2,3]' => '1,2,3')
        #   $3:: The modifier string.
        #        (ex: '--[]i' => 'i', '--1[1,2,3]is' => 'is')
        #
        def bracket_regexp(l, r)
          /\A--(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}([A-z]*)\z/
        end
        
        # The escape begin argument
        ESCAPE_BEGIN = "-."

        # The escape end argument
        ESCAPE_END = ".-"

        # The parser end flag
        END_FLAG = "---"

        # Matches any breaking arg (ex: '--', '--+', '--1:2')
        BREAK =  /\A--(\z|[\+\d\:\*\[\{\(])/

        # Matches the start of any workflow regex (ex: '+', '2', '[', '{')
        WORKFLOW =  /\A[\+\d\:\*\[\{\(]/

        # Matches an execution-round break.  After the match:
        #
        #   $2:: The round string after the break, or nil. 
        #        (ex: '--' => nil, '--++' => '++', '--+1' => '+1')
        #   $5:: The target string, or nil. 
        #        (ex: '--+' => nil, '--+[1,2,3]' => '1,2,3')
        #
        ROUND = /\A--(\z|(\+(\d*|\+*))(\[([\d,]*)\])?\z)/

        # Matches a sequence break.  After the match:
        #
        #   $1:: The sequence string after the break. 
        #        (ex: '--:' => ':', '--1:2' => '1:2', '--1:' => '1:', '--:2' => ':2')
        #   $3:: The modifier string.
        #        (ex: '--:i' => 'i', '--1:2is' => 'is')
        #
        SEQUENCE = /\A--(\d*(:\d*)+)([A-z]*)\z/

        # Matches an instance break.  After the match:
        #
        #   $1:: The index string after the break.
        #        (ex: '--*' => '', '--*1' => '1')
        #
        INSTANCE = /\A--\*(\d*)\z/

        # A break regexp using "[]"
        FORK = bracket_regexp("[", "]")

        # A break regexp using "{}"
        MERGE = bracket_regexp("{", "}")

        # A break regexp using "()"
        SYNC_MERGE = bracket_regexp("(", ")")
        
        # Parses an indicies str along commas, and collects the indicies
        # as integers. Ex:
        #
        # parse_indicies('') # => []
        # parse_indicies('1') # => [1]
        # parse_indicies('1,2,3') # => [1,2,3]
        #
        def parse_indicies(str, regexp=/,+/)
          indicies = []
          str.split(regexp).each do |n|
            indicies << n.to_i unless n.empty?
          end
          indicies
        end
 
        # Parses the match of a ROUND regexp into a round index
        # and an array of task indicies that should be added to the
        # round. The inputs correspond to $3 and $6 for the match.
        #
        # If $3 is nil, a round index of zero is assumed; if $6 is
        # nil or empty, then indicies of [:current_index] are assumed.
        #
        # parse_round("+", "") # => [1, [:current_index]]
        # parse_round("+2", "1,2,3") # => [2, [1,2,3]]
        # parse_round(nil, nil) # => [0, [:current_index]]
        #
        def parse_round(three, six)
          index = case three
          when nil then 0
          when /\d/ then three[1, three.length-1].to_i
          else three.length
          end
          [index, six.to_s.empty? ? [current_index] : parse_indicies(six)]
        end
 
        # Parses the match of a SEQUENCE regexp into an array of task
        # indicies. The input corresponds to $2 for the match. The
        # previous and current index are assumed if $2 starts and/or ends
        # with a semi-colon.
        #
        # parse_sequence("1:2:3") # => [1,2,3]
        # parse_sequence(":1:2:") # => [:previous_index,1,2,:current_index]
        #
        def parse_sequence(two)
          seq = parse_indicies(two, /:+/)
          seq.unshift previous_index if two[0] == ?:
          seq << current_index if two[-1] == ?:
          seq
        end
      
        # Parses the match of an INSTANCE regexp into an index.
        # The input corresponds to $2 for the match. The current
        # index is assumed if $2 is empty.
        #
        # parse_instance("1") # => 1
        # parse_instance("") # => :current_index
        #
        def parse_instance(two)
          two.empty? ? current_index : two.to_i
        end
 
        # Parses the match of an bracket_regexp into a [source_index,
        # target_indicies] array. The inputs corresponds to $2 and
        # $3 for the match. The previous and current index are assumed
        # if $2 and/or $3 is empty.
        #
        # parse_bracket("1", "2,3") # => [1, [2,3]]
        # parse_bracket("", "") # => [:previous_index, [:current_index]]
        # parse_bracket("1", "") # => [1, [:current_index]]
        # parse_bracket("", "2,3") # => [:previous_index, [2,3]]
        #
        def parse_bracket(two, three)
          targets = parse_indicies(three)
          targets << current_index if targets.empty?
          [two.empty? ? previous_index : two.to_i, targets]
        end
        
        def parse_options(three)
          {}
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
      # splits it into an array using Shellwords.
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
      #   p = Parser.new "a -- b --+ c -- d -- e --+3[4]"
      #   p.rounds                   # => [[0,1,3],[2], nil, [4]]
      #
      # ==== Workflow Assignment
      # All simple workflow patterns except switch can be specified within
      # the parse syntax (switch is the exception because there is no good
      # way to define a block from an array).  
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
      # parsed with essentially the same code, only reversing the source
      # and target in the case of merges.
      #
      # Here a and b are sequenced inline.  Task c is assigned to no 
      # workflow until the final argument which sequenced b and c.
      #
      #   p = Parser.new "a --: b -- c --1:2i"
      #   p.argvs                    # => [["a"], ["b"], ["c"]]
      #   p.workflow(:sequence)      # => [[0,[1],''],[1,[2],'i']]
      #
      # ==== Globals
      # Global instances of task (used, for example, by dependencies) may
      # be assigned in the parse syntax as well.  The break for a global
      # is '--*'.
      #
      #   p = Parser.new "a -- b --* global_name --config for --global"
      #   p.globals                  # => [2]
      #
      # ==== Escapes and End Flags
      # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
      # any number of arguments may be enclosed within the escape. After the 
      # end delimiter, breaks are active once again.
      #
      #   p = Parser.new "a -- b -- c"
      #   p.argvs                    # => [["a"], ["b"], ["c"]]
      # 
      #   p = Parser.new "a -. -- b .- -- c"
      #   p.argvs                    # => [["a", "--", "b"], ["c"]]
      #
      # Parsing continues until the end of argv, or a an end flag '---' is 
      # reached.  The end flag may also be escaped.
      #
      #   p = Parser.new "a -- b --- c"
      #   p.argvs                    # => [["a"], ["b"]]
      #
      #--
      # === Examples
      # Parse two tasks, with inputs and configs at separate times.  Both 
      # are assigned to round 0.
      #
      #   p = Parser.new
      #   p.parse(["a", "b", "--config", "c"])
      #   p.tasks          
      #   # => [
      #   # ["a", "b", "--config", "c"]]
      #
      #   p.parse(["x", "y", "z"])
      #   p.tasks          
      #   # => [
      #   # ["a", "b", "--config", "c"],
      #   # ["x", "y", "z"]]
      #   
      #   p.rounds         # => [[0,1]]
      #
      # Parse two simple tasks at the same time into different rounds.
      #
      #   p = Parser.new ["a", "--+", "b"]
      #   p.tasks          # => [["a"], ["b"]]
      #   p.rounds         # => [[0], [1]]
      #
      # Rounds can be declared multiple ways:
      #
      #   p = Parser.new ["--+", "a", "--", "b", "--", "c", "--", "d"]
      #   p.tasks          # => [["a"], ["b"], ["c"], ["d"]]
      #   p.rounds         # => [[1,2,3], [0]]
      #
      #   p.parse ["+3[2,3]"]
      #   p.rounds         # => [[1], [0], nil, [2,3]]
      #
      # Note the rounds were re-assigned using the second parse.  Very
      # similar things may be done with workflows (note also that this
      # example shows how parse splits a string input into an argv 
      # using Shellwords):
      #
      #   p = Parser.new "a --: b --: c --: d"
      #   p.tasks                   # => [["a"], ["b"], ["c"], ["d"]]
      #   p.workflow(:sequence)     # => [[0,1],[1,2],[2,3]]
      #
      #   p.parse "1[2,3]"
      #   p.workflow(:sequence)     # => [[0,1],[2,3]]
      #   p.workflow(:fork)         # => [[1,[2,3]]]
      #
      #   p.parse "e --{2,3}"
      #   p.tasks                   # => [["a"], ["b"], ["c"], ["d"], ["e"]]
      #   p.workflow(:sequence)     # => [[0,1]]
      #   p.workflow(:fork)         # => [[1,[2,3]]]
      #   p.workflow(:merge)        # => [[4,[2,3]]]
      #
      # Use escapes ('-.' and '.-') to bring breaks into a task array.  Any
      # number of breaks/args may occur within an escape sequence; breaks
      # are re-activated after the stop-escape:
      #
      #   p = Parser.new "a -. -- b -- .- c -- d"
      #   p.tasks                   # => [["a", "--", "b", "--", "c"], ["d"]]
      #
      # Use the stop delimiter to stop parsing (the unparsed argv is 
      # returned by parse):
      #
      #   argv = ["a", "--", "b", "---", "args", "after", "stop"]
      #   p = Parser.new
      #   p.parse(argv)             # => ["args", "after", "stop"]
      #   p.tasks                   # => [["a"], ["b"]]
      #
      def parse(argv)
        parse!(argv.kind_of?(String) ? argv : argv.dup)
      end

      # Same as parse, but removes parsed args from argv.
      def parse!(argv)
        if argv.kind_of?(String)
          argv = Shellwords.shellwords(argv)
        end
        argv.unshift('--')

        current_argv = schema[current_index].argv        
        escape = false
        while !argv.empty?
          arg = argv.shift

          # if escaping, add escaped arguments 
          # until an escape-end argument
          if escape
            if arg == ESCAPE_END
              escape = false
            else
              current_argv << arg
            end

            next
          end

          # begin escaping if indicated
          if arg == ESCAPE_BEGIN
            escape = true
            next
          end

          # break on an end-flag
          break if arg == END_FLAG

          # add all other non-breaking args to
          # the current argv; this includes
          # both inputs and configurations
          unless arg =~ BREAK || (current_argv.empty? && arg =~ WORKFLOW)
            current_argv << arg
            next  
          end

          # a breaking argument was reached:
          # unless the current argv is empty,
          # append and start a new definition
          unless current_argv.empty?
            self.current_index += 1
            current_argv = schema[current_index].argv
          end

          # determine the type of break and modify
          # task definitions appropriately
          case arg
          when ROUND
            round, indicies = parse_round($2, $5)
            indicies.each {|index| schema[index].source = round }

          when SEQUENCE
            indicies = parse_sequence($1)
            options = parse_options($3)
            while indicies.length > 1
              schema.set(:sequence, options, indicies.shift, indicies[0])
            end

          when INSTANCE    then schema[parse_instance($1)].reset
          when FORK        then schema.set(:fork,       parse_options($3), *parse_bracket($1, $2))
          when MERGE       then schema.set(:merge,      parse_options($3), *parse_bracket($1, $2))
          when SYNC_MERGE  then schema.set(:sync_merge, parse_options($3), *parse_bracket($1, $2))
          else raise ArgumentError, "invalid break argument: #{arg}"
          end
        end

        schema
      end
      
      protected
      
      # The index of the node currently being parsed.
      attr_accessor :current_index
      
      # Returns current_index-1, or raises an error if current_index < 1.
      def previous_index
        raise ArgumentError, 'there is no previous index' if current_index < 1
        current_index - 1
      end
      
    end
  end
end