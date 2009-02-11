module Tap
  module Support

    # Represents a task node in a Schema.
    class Node
      
      # An array of arguments used to instantiate
      # the node
      attr_accessor :argv
      
      # The input or source for the node.  Inputs
      # may be a Join, nil, or an Integer.  An 
      # Integer input indicates that the node should 
      # be enqued to a round using argv as inputs.
      attr_reader :input
      
      # The output for the node. Output may be a
      # a Join or nil.
      attr_reader :output

      def initialize(argv=[], input=nil, output=nil)
        @argv = argv
        @input = @output = nil
        self.input = input
        self.output = output
      end
      
      def input=(value)
        if @input.kind_of?(Join)
          @input.targets.delete(self)
        end
        
        @input = value
        
        if @input.kind_of?(Join)
          @input.targets << self
        end
      end
      
      def output=(value)
        if @output.kind_of?(Join)
          @output.sources.delete(self)
        end
        
        @output = value
        
        if @output.kind_of?(Join)
          @output.sources << self
        end
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