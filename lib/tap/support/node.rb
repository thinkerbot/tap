module Tap
  module Support

    # Represents a task node in a Schema.
    class Node
      class Join 
        attr_reader :type
        attr_reader :options
        
        def initialize(type, options)
          @type = type
          @options = options
        end
        
        def inspect
          "#<Join:#{object_id}>"
        end
      end
      
      class ReverseJoin < Join
        def inspect
          "#<ReverseJoin:#{object_id}>"
        end
      end

      # An array of arguments used to instantiate
      # the node, and to specify arguments enqued
      # to the instance (when the node is directly
      # enqued to a round... see input)
      attr_accessor :argv
      
      # The input or source for the node.  Inputs
      # may be a Join, nil, or an Integer (indicating
      # the node should be enqued to a round, with 
      # inputs as specified in argv).
      attr_accessor :input
      
      # The output for the node. Output may be a
      # a Join or nil.
      attr_accessor :output

      def initialize(argv=[], input=nil, output=nil)
        @argv = argv
        @input = input
        @output = output
      end
      
      # Resets the source and join to nil.
      def globalize
        self.input = nil
        self.output = nil
      end
      
      # True if the input and output are nil.
      def global?
        input == nil && output == nil
      end
      
      # Returns the round for self; a round is indicated
      # by an integer input.  If input is anything but 
      # an integer, round returns nil.
      def round
        input.kind_of?(Integer) ? input : nil
      end
      
      # Alias for input=
      def round=(input)
        self.input = input
      end
      
      def inspect
        "#<#{self.class}:#{object_id} argv=[#{argv.join(' ')}] input=#{input.inspect} output=#{output.inspect}>"
      end

    end
  end
end