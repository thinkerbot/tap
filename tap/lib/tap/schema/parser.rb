module Tap
  class Schema
    
    # == Syntax
    #
    # The command line syntax can be thought of as a series of ARGV arrays
    # connected by breaks.  The arrays define nodes in a workflow while the
    # breaks define joins.  These are the available breaks:
    #
    #   break          meaning
    #   --             default delimiter, no join
    #   --:            sequence join
    #   --[][]         general join syntax
    #
    # As an example, this defines three nodes (a, b, c) and sequences the
    # b and c nodes:
    #
    #   schema = Parser.new("a -- b --: c").schema
    #   schema.nodes.collect {|node| node.metadata }
    #   # => [["a"], ["b"], ["c"]]
    #
    #   a,b,c = schema.nodes
    #   a.output                      # => nil
    #   b.output.class                # => Tap::Schema::Join
    #   b.output == c.input           # => true
    #
    # In the example, the indicies of the nodes participating in the sequence
    # are inferred as the last and next nodes in the schema, and obviously the
    # location of the sequence break is significant.  By contrast, the break
    # order doesn't matter when you directly specify the nodes in a join.
    # These both sequence a to b, and b to c.
    #
    #   schema = Parser.new("a -- b -- c --0:1 --1:2").schema
    #   a,b,c = schema.nodes
    #   a.output == b.input           # => true
    #   b.output == c.input           # => true
    #
    #   schema = Parser.new("a --1:2 --0:1 b -- c").schema
    #   a,b,c = schema.nodes
    #   a.output == b.input           # => true
    #   b.output == c.input           # => true
    #
    # ==== General Join Syntax
    #
    # The general join syntax allows the specification of arbitrary joins.
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
    # of a simple multi-way join.  Internally the breaks are interpreted like
    # this:
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
    # ==== Escapes and End Flags
    #
    # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
    # any number of arguments may be enclosed within the escape. After the 
    # end delimiter, breaks are active once again.
    #
    #   schema = Parser.new("a -- b -- c").schema
    #   schema.metadata               # => [["a"], ["b"], ["c"]]
    # 
    #   schema = Parser.new("a -. -- b .- -- c").schema
    #   schema.metadata               # => [["a", "--", "b"], ["c"]]
    #
    # Parsing continues until the end of argv, or a an end flag '---' is 
    # reached.  The end flag may also be escaped.
    #
    #   schema = Parser.new("a -- b --- c").schema
    #   schema.metadata               # => [["a"], ["b"]]
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
        SEQUENCE = /\A(\d*(?::\d*)+)([A-z]*)\z/
        
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
          
          metadata = ['join', two]
          sequences = []
          while indicies.length > 1
            sequences << [[indicies.shift], [indicies[0]], metadata]
          end
          sequences
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
          [inputs, outputs, [join_type, three]]
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
            args = args.inject({}) {|hash, (k,v)| hash[k.to_sym] = v; hash }
            
            case
            when args.has_key?(:round) && args.has_key?(:indicies)
              schema.set_round(args[:round], args[:indicies])
            when args.has_key?(:inputs) && args.has_key?(:outputs)
              schema.set_join(args[:inputs], args[:outputs], args[:metadata])
            when args.has_key?(:prerequisites)
              schema.set_prerequisites args[:prerequisites]
            when args.has_key?(:id)
              schema.nodes << Node.new(args)
              self.current_index += 1
            else
              raise "invalid arg: #{args}"
            end
            
          when Array
            schema.nodes << Node.new(args)
            self.current_index += 1
            
          when String
            args.split(/\s/).each do |arg|
              parse_break(arg)
            end
            
          when nil
          else raise "invalid arg: #{args}"
          end
        end
        
        # cleanup is currently required if terminal joins like
        # --0[] are allowed (since it's interpreted as --0[next])
        schema.cleanup
      end
      
      protected
      
      # The index of the node currently being parsed.
      attr_accessor :current_index # :nodoc:
      
      def argv(index) # :nodoc:
        schema[index].metadata ||= []
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
          # standard break, do nothing
        when SEQUENCE     
          parse_sequence($1, $2).each {|join| schema.set_join(*join) }
        when JOIN         
          schema.set_join(*parse_join($1, $2, $3, $4))
        else
          raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
    end
  end
end