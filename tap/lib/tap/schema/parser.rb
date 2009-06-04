require 'shellwords'
require 'tap/schema'

module Tap
  class Schema
    class << self
      def parse(argv=ARGV)
        Parser.new(argv).schema
      end
    end
    
    # A parser for workflow schema defined on the command line.
    #
    # == Syntax
    #
    # The command line syntax can be thought of as a series of ARGV arrays
    # connected by breaks.  The arrays define tasks (ie nodes) in a workflow
    # while the breaks define joins.  These are the available breaks:
    #
    #   break          meaning
    #   --             default delimiter, no join
    #   --:            sequence join
    #   --[][]         multi-join (sequence, fork, merge)
    #
    # As an example, this defines three tasks (a, b, c) and sequences the
    # b and c tasks:
    #
    #   schema = Parser.new("a -- b --: c").schema
    #   schema.tasks                  # => [["a"], ["b"], ["c"]]
    #   schema.joins                  # => [['join', [1],[2]]]
    #
    # In the example, the indicies of the tasks participating in the sequence
    # are inferred as the last and next tasks in the schema.  Alternatively
    # the tasks participating in the sequence may be written out directly;
    # these also sequence b to c.
    #
    #   schema = Parser.new("a -- b -- c --1:2").schema
    #   schema.tasks                  
    #   # => {
    #   # 0 => ["a"], 
    #   # 1 => ["b"], 
    #   # 2 => ["c"]
    #   # }
    #   schema.joins                  
    #   # => [
    #   # [[1],[2]]
    #   # ]
    #
    #   schema = Parser.new("a --1:2 b -- c").schema
    #   schema.tasks
    #   # => {
    #   # 0 => ["a"], 
    #   # 1 => ["b"], 
    #   # 2 => ["c"]
    #   # }
    #   schema.joins                  
    #   # => [
    #   # [[1],[2]]
    #   # ]
    #
    # ==== Multi-Join Syntax
    #
    # The multi-join syntax allows the specification of arbitrary joins.
    # Starting with a few examples:
    #
    #   example        meaning
    #   --[][]         last.sequence(next)
    #   --[1][2]       1.sequence(2)
    #   --[1][2,3]     1.fork(2,3)
    #   --[1,2][3]     3.merge(1,2)
    #
    # The meaning of the bracket breaks seems to be changing but note that
    # the sequences, forks, and (unsynchronized) merges are all variations
    # of a multi-way join.  Internally the breaks are interpreted like this:
    #
    #   join = Join.new
    #   join.join(inputs, outputs)
    #
    # To specify another class of join, or to specify join configurations,
    # add a string in the format "configs.class" where the configs are the
    # single-letter configuration flags and class is a lookup for the join
    # class.
    #
    #   example        interpretation
    #   --:s           Join.new(:splat => true)
    #   --1:2is        Join.new(:iterate => true, :splat => true)
    #   --[][]q.sync   Sync.new(:enq => true)
    #   --[][].sync    Sync.new
    #
    # If you can stand the syntax, you can also specify a full argv after
    # the bracket, just be sure to enclose the whole break in quotes.
    #
    #   example                interpretation
    #   "--1:2 join -i -s"     Join.new(:iterate => true, :splat => true)
    #   "--[][] sync --enq"    Sync.new(:enq => true)
    #
    # ==== Escapes and End Flags
    #
    # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
    # any number of arguments may be enclosed within the escape. After the 
    # end delimiter, breaks are active once again.
    #
    #   schema = Parser.new("a -- b -- c").schema
    #   schema.tasks
    #   # => {
    #   # 0 => ["a"], 
    #   # 1 => ["b"], 
    #   # 2 => ["c"]
    #   # }
    # 
    #   schema = Parser.new("a -. -- b .- -- c").schema
    #   schema.tasks
    #   # => {
    #   # 0 => ["a", "--", "b"], 
    #   # 1 => ["c"]
    #   # }
    #
    # Parsing continues until the end of argv, or a an end flag '---' is 
    # reached.  The end flag may also be escaped.
    #
    #   schema = Parser.new("a -- b --- c").schema
    #   schema.tasks
    #   # => {
    #   # 0 => ["a"], 
    #   # 1 => ["b"]
    #   # }
    #
    class Parser
      
      # A set of parsing routines used internally by Tap::Schema::Parser,
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
        #        (ex: '--' => '', '--:' => ':', '--[1,2][3,4]is.join' => '[1,2][3,4]is.join')
        #
        BREAK =  /\A--(\z|[\d\:\[].*\z)/

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
        SEQUENCE = /\A(\d*(?::\d*)+)(.*)\z/
        
        # Matches a generic join break. Examples:
        #
        #   "[1,2,3][4,5,6] join -i -s"
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
        #
        JOIN = /\A\[([\d,]*)\]\[([\d,]*)\](.*)\z/
        
        # Matches a join modifier. After the match:
        #
        #   $1:: The modifier flag string.
        #        (ex: 'is.sync' => 'is')
        #   $2:: The class string.
        #        (ex: 'is.sync' => 'sync')
        #
        JOIN_MODIFIER = /\A([A-z]*)(?:\.(.*))?\z/
        
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

        # Parses the match of a SEQUENCE regexp an array of [input_indicies,
        # output_indicies, metadata] arrays. The inputs corresponds to $1 and
        # $2 for the match. The previous and current index are assumed if $1
        # starts and/or ends with a semi-colon.
        #
        #   parse_sequence("1:2:3", '')
        #   # => [
        #   # [[1], [2]],
        #   # [[2], [3]],
        #   # ]
        #
        #   parse_sequence(":1:2:", 'is')
        #   # => [
        #   # [[:previous_index], [1], ['join', '-i', '-s']],
        #   # [[1], [2], ['join', '-i', '-s']]],
        #   # [[2], [:current_index], ['join', '-i', '-s']],
        #   # ]
        #
        def parse_sequence(one, two)
          indicies = parse_indicies(one, /:+/)
          indicies.unshift previous_index if one[0] == ?:
          indicies << current_index if one[-1] == ?:
          
          sequences = []
          while indicies.length > 1
            sequences << [[indicies.shift], [indicies[0]]]
          end
          
          if argv = parse_join_modifier(two)
            sequences.each do |sequence|
              sequence << argv
            end
          end
          
          sequences
        end

        # Parses the match of a JOIN regexp into a [input_indicies,
        # output_indicies, metadata] array. The inputs corresponds to $1, $2,
        # and $3 for a match to a JOIN regexp.  A join type of  'join' is
        # assumed unless otherwise specified.
        #
        #   parse_join("1", "2,3", "")         # => [[1], [2,3]]
        #   parse_join("", "", "is.type")      # => [[], [], ['type', '-i', '-s']]
        #   parse_join("", "", "type -i -s")   # => [[], [], ['type', '-i', '-s']]
        #
        def parse_join(one, two, three)
          join = [parse_indicies(one), parse_indicies(two)]
          
          if argv = parse_join_modifier(three)
            join << argv
          end
          
          join
        end
        
        # Parses a join modifier string into an argv.
        def parse_join_modifier(modifier)
          case modifier
          when ""
            nil
          when JOIN_MODIFIER
            argv = [$2 == nil || $2.empty? ? 'join' : $2]
            $1.split("").each {|char| argv << "-#{char}"}
            argv
          else
            Shellwords.shellwords(modifier)
          end
        end
      end
      
      include Utils
      
      # The schema into which tasks are being parsed
      attr_reader :schema
      
      def initialize(argv=[])
        parse(argv)
      end

      # Iterates through the argv splitting out task and join definitions.
      # Parse is non-destructive to argv.  If a string argv is provided, parse
      # splits it into an array using Shellwords; if a hash argv is provided,
      # parse converts it to an array using Parser::Utils#parse_argh.
      def parse(argv)
        parse!(argv.kind_of?(String) ? argv : argv.dup)
      end

      # Same as parse, but removes parsed args from argv.
      def parse!(argv)
        @schema = Schema.new
        
        # prevent the addition of an empty task to schema
        return schema if argv.empty?
        
        argv = Shellwords.shellwords(argv) if argv.kind_of?(String)
        argv.unshift('--') unless argv[0] =~ BREAK
        
        @current_index = -1
        @current_task = nil
        escape = false
        while !argv.empty?
          arg = argv.shift

          # if escaping, add escaped arguments 
          # until an escape-end argument
          if escape
            if arg == ESCAPE_END
              escape = false
            else
              current_task << arg
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
            # a breaking argument was reached
            @current_index += 1
            @current_task = nil
            
            # parse the break string for any
            # schema modifications
            parse_break($1)
            
          else
            # add all other non-breaking args to
            # the current argv; this includes
            # both inputs and configurations
            current_task << arg
            
          end
        end
        
        # determine the queue as all tasks not
        # used as a join output
        queue = schema.tasks.keys
        schema.joins.each {|join| queue -= join[1] }
        schema.queue.concat(queue)
        
        schema
      end
      
      protected
      
      # The index of the task currently being parsed.
      attr_reader :current_index # :nodoc:
      
      def current_task
        @current_task ||= task(current_index)
      end
      
      # helper to initialize a task at the specified index
      def task(index) # :nodoc:
        schema.tasks[index] ||= []
      end
      
      # returns current_index-1, or raises an error if current_index < 1.
      def previous_index # :nodoc:
        current_index - 1
      end
      
      # determines the type of break and modifies self appropriately
      def parse_break(arg) # :nodoc:
        case arg
        when ""
        when SEQUENCE
          schema.joins.concat parse_sequence($1, $2)
        when JOIN
          schema.joins << parse_join($1, $2, $3)
        else
          raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
    end
  end
end