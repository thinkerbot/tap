module Tap
  class Schema

    # Represents a join in a Schema.
    class Join
      
      # Metadata used to instantiate the join.  May be a hash or an array.
      attr_accessor :metadata
      
      # An array of node inputs for the join.
      attr_reader :inputs
      
      # An array of node outputs for the join.
      attr_reader :outputs
      
      def initialize(inputs=[], outputs=[], metadata=nil)
        @metadata = metadata
        @inputs = inputs
        @outputs = outputs
      end
      
      # Returns true if the join has no inputs.
      def orphan?
        inputs.empty?
      end
      
      # Detaches the join from its outputs.
      def detach!
        outputs.dup.each {|node| node.input = nil}
      end
    end
  end
end