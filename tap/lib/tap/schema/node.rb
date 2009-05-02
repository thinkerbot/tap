require 'tap/schema/join'

module Tap
  class Schema

    # Represents a node in a Schema.
    class Node
      
      # Metadata used to instantiate the node.  May be a hash or an array.
      attr_accessor :metadata
      
      # The input for the node.  Input may be a join or nil.
      attr_reader :input
      
      # The output for the node.  Output may be a join or nil.
      attr_reader :output
      
      def initialize(metadata=nil, input=nil, output=nil)
        @metadata = metadata
        @input = @output = nil
        
        self.input = input
        self.output = output
      end
      
      # Returns true if metadata is not set or is empty.
      def empty?
        metadata == nil || metadata.empty? 
      end
      
      # Returns an array of nodes that pass inputs to self via a join.
      # If input is not a join, parents is an empty array.
      def parents
        input ? input.inputs : []
      end
      
      # Returns an array of nodes that receive the outputs of self via
      # a join.  If output is not a join, children is an empty array.
      def children
        output ? output.outputs : []
      end
      
      # Sets the input for self.
      def input=(value)
        if input
          input.outputs.delete(self)
        end
        
        if value
          value.outputs << self
        end
        
        @input = value
      end
      
      # Sets the output for self.
      def output=(value)
        if output
          output.inputs.delete(self)
          
          # cleanup orphan joins
          if output.orphan?
            output.detach!
          end
        end
        
        if value
          value.inputs << self
        end
        
        @output = value
      end
    end
  end
end