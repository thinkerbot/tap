require 'tap/support/batchable_methods'

module Tap
  module Support

    # Batchable encapsulates the methods used to support batching
    # of tasks. See the 'Batches' section in the Tap::Task 
    # documentation for more details on how Batchable works in 
    # practice.
    module Batchable
      #extend Support::BatchableMethods
      
      def self.included(mod)
        mod.extend Support::BatchableMethods if mod.kind_of?(Class)
      end
      
      # The object batch.
      attr_reader :batch
      
      def initialize(batch=[])
        @batch = batch
        @batch << self
      end
    
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
      # The object will be a duplicate of self.
      def initialize_batch_obj
        obj = self.dup
        batch << obj
        obj
      end
    end
  end
end