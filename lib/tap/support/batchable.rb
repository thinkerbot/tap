module Tap
  module Support

    # Batchable encapsulates the methods used to support batching
    # of tasks. See the 'Batches' section in the Tap::Task 
    # documentation for more details on how Batchable works in 
    # practice.
    module Batchable
      extend Support::BatchableMethods
      
      # The object batch. (must be initializd by classes that
      # include Batchable)
      attr_reader :batch
    
      # Returns true if the batch size is greater than one 
      # (the one being self).  
      def batched?
        batch.length > 1
      end

      # Returns the index of the self in batch.
      def batch_index
        batch.index(self)
      end   
      
      # Initializes a new batch object and adds the object to batch.
      # The object will be self if batch is empty (ie for the first
      # call) or a duplicate of self if not.
      def initialize_batch_obj
        obj = (batch.empty? ? self : self.dup)
        batch << obj
        obj
      end
    end
  end
end