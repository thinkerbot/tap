require 'tap/support/join'

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
      
      # Returns the round for self; a round is indicated by an integer input. 
      # If input is anything but an integer, round returns nil.
      def round
        input.kind_of?(Integer) ? input : nil
      end
      
      # Alias for input=
      def round=(input)
        self.input = input
      end
      
      # Returns the natural round of a node.  If a round is set then the
      # natural round is the round.  If no round is set (ie input is a Join)
      # then the natural round is that of the first source node with a natural
      # round.
      #
      #   # (0)-o-[A]-o-[C]-o-[D]
      #   #           |
      #   # (1)-o-[B]-o
      #
      #   join1, join2 = Array.new(2) { Join.new }
      #   a = Node.new [], 0, join1
      #   b = Node.new [], 1, join1
      #   c = Node.new [], join1, join2
      #   d = Node.new [], join2
      #
      #   d.natural_round             # => 0
      #
      # Tracking back, the natural round of D is 0.  Source order matters and
      # globals are ignored.
      #
      #   # ( )-o-[A]-o
      #   #           |
      #   # (1)-o-[B]-o
      #   #           |
      #   # (0)-o-[C]-o-[D]
      #
      #   join = Join.new
      #   a = Node.new [], nil, join
      #   b = Node.new [], 1, join
      #   c = Node.new [], 0, join
      #   d = Node.new [], join
      #
      #   d.natural_round             # => 1
      #
      def natural_round
        case input
        when Integer then input
        when Join
          
          input.sources.each do |source_node|
            if natural_round = source_node.natural_round
              return natural_round
            end
          end
          nil
          
        else nil
        end
      end
      
      def inspect
        "#<#{self.class}:#{object_id} argv=[#{argv.join(' ')}] input=#{input.inspect} output=#{output.inspect}>"
      end

    end
  end
end