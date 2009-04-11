module Tap
  module Support

    # Represents a task node in a Schema.
    class Node
      class << self
        
        # Returns the natural round of a set of nodes.  The natural round is
        # the lowest round of any of the nodes, or the node ancestors.
        #
        #   # (3)-o-[A]-o-[C]-o-[D]
        #   #           |
        #   # (2)-o-[B]-o
        #
        #   join1, join2 = Array.new(2) { [:join, [], []] }
        #   a = Node.new [], 3, join1
        #   b = Node.new [], 2, join1
        #   c = Node.new [], join1, join2
        #   d = Node.new [], join2
        #
        #   Node.natural_round([d])              # => 2
        #
        # Tracking back, the natural round of D is 2.  Node order does not
        # matter and globals are ignored.
        #
        #   # ( )-o-[E]-o
        #   #           |
        #   # (1)-o-[F]-o
        #   #           |
        #   # (2)-o-[G]-o-[H]
        #
        #   join = [:join, [], []]
        #   e = Node.new [], nil, join
        #   f = Node.new [], 1, join
        #   g = Node.new [], 2, join
        #   h = Node.new [], join
        #
        #   Node.natural_round([d, h])           # => 1
        #
        def natural_round(nodes, visited=[])
          round = nil
          nodes.each do |node|
            next if visited.include?(node)
            visited << node
            
            case input = node.input
            when Integer
              
              # reassign current round if necesssary
              unless round && round < input
                round = input
              end
              
            when Array
              round = natural_round(node.parents, visited)
            end
            
            # optimization; no round is less than 0
            return 0 if round == 0
          end
          
          round || 0
        end
      end
      
      # Metadata used to instantiate the node.  May be a hash or an array.
      attr_accessor :metadata
      
      # The input for the node.  Input may be:
      #
      # - a join array: [join_instance, input_nodes, output_nodes]
      # - an Integer indicating the round for self
      # - nil signifiying 'global'
      #
      attr_reader :input
      
      # The output for the node.  Output may be:
      #
      # - a join array: [join_instance, input_nodes, output_nodes]
      # - nil signifying nothing
      #
      attr_reader :output

      def initialize(metadata=nil, input=0, output=nil)
        @metadata = metadata
        @input = @output = nil
        
        self.input = input
        self.output = output
      end
      
      # Returns true if metadata is not set or is empty.
      def empty?
        metadata == nil || metadata.empty? 
      end
      
      # Returns the input join if the input to self is a join array.
      def input_join
        input.kind_of?(Array) ? input : nil
      end
      
      # Returns the output join if the output of self is a join array.
      def output_join
        output.kind_of?(Array) ? output : nil
      end
      
      # Returns an array of nodes that pass inputs to self via an input join.
      # If input is not a join, parents is an empty array.
      def parents
        input.kind_of?(Array) ? input[0] : []
      end
      
      # Returns an array of nodes that receive the outputs self via an output
      # join.  If output is not a join, children is an empty array.
      def children
        output.kind_of?(Array) ? output[1] : []
      end
      
      # Sets the input for self.
      def input=(value)
        if input.kind_of?(Array)
          input[1].delete(self)
        end
        
        if value.kind_of?(Array)
          value[1] << self
        end
        
        @input = value
      end
      
      # Sets the output for self.
      def output=(value)
        if output.kind_of?(Array)
          output[0].delete(self)
          
          # cleanup orphan joins
          if output[0].empty?
            orphan_round = natural_round
            output[1].dup.each {|node| node.input = orphan_round }
          end
        end
        
        if value.kind_of?(Array)
          value[0] << self
        end
        
        @output = value
      end
      
      # Sets the input to nil.
      def make_prerequisite
        self.input = nil
      end
      
      # True if the input is nil.
      def prerequisite?
        input == nil
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
      
      # Returns the natural round for self.
      def natural_round
        Node.natural_round([self])
      end
      
      def inspect
        "#<#{self.class}:#{object_id} argh=#{argh.inspect} input=#{input.inspect} output=#{output.inspect}>"
      end

    end
  end
end