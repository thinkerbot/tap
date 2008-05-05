module Tap
  module Support
    
    # BatchableMethods encapsulates class methods related to Batchable.
    module BatchableMethods
      
      # Merges the batches for the specified objects.  All objects 
      # sharing the individual object batches will be affected, even 
      # if they are not listed explicitly as an input.
      #
      #  t1 = Tap::Task.new
      #  t2 = Tap::Task.new
      #  t3 = t2.initialize_batch_obj
      #
      #  Batchable.batch(t1, t2)
      #  t3.batch                    # => [t1,t2,t3]
      #
      # Returns the new batch.
      def batch(*batchables)
        merged = []
        batches = batchables.collect {|batchable| batchable.batch }.uniq
        batches.each do |batch| 
           merged.concat(batch)
           batch.clear
         end
        merged.uniq!
        batches.each {|batch| batch.concat(merged) }
        merged
      end
      
      protected
      
      # def batch_function(*methods)
      #   methods.each do |method|
      #     unbatched_method = "unbatched_#{method}"
      #     next if method_defined?(unbatched_method)
      #     
      #     class_eval %Q{
      #       alias #{unbatched_method} #{method}
      #       def #{method}(*args)
      #         batch.each {|t| t.#{unbatched_method}(*args) }
      #         self
      #       end
      #     }
      #   end
      # end
      # 
      # def batch_block_function(*methods)
      #   methods.each do |method|
      #     unbatched_method = "unbatched_#{method}"
      #     next if method_defined?(unbatched_method)
      #     
      #     class_eval %Q{
      #       alias #{unbatched_method} #{method}
      #       def #{method}(*args, &block)
      #         batch.each {|t| t.#{unbatched_method}(*args, &block) }
      #         self
      #       end
      #     }
      #   end
      # end
      
    end 
  end
end