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
      #  Tap::Task.batch(t1, t2)
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
      
      # Redefines the specified method(s) as batched methods.  The existing method
      # is renamed as <tt>unbatched_method</tt> and <tt>method</tt> redefined to 
      # call <tt>unbatched_method</tt> on each object in the batch.
      #
      #   def process(one, two)
      #     ...
      #   end
      #   batch_function(:process)
      #
      # Is equivalent to:
      #
      #   def unbatched_process(one, two)
      #     ...
      #   end
      #
      #   def process(one, two)
      #     batch.each do |t|
      #      t.unbatched_process(one, two)
      #     end
      #     self
      #   end
      #
      # The batched method will accept/pass as many arguments as are defined for
      # the unbatched method.  Splats are supported, and blocks are supported too 
      # by passing a block to batch_function:
      #
      #   def process(arg, *args, &block)
      #     ...
      #   end
      #   batch_function(:process) {}
      #
      # Is equivalent to:
      #
      #   def unbatched_process(arg, *args, &block)
      #     ...
      #   end
      #
      #   def process(*args, &block)
      #     batch.each do |t|
      #      t.unbatched_process(*args, &block)
      #     end
      #     self
      #   end
      #
      # Obviously there are limitations to batch_function, most notably batching
      # functions with default values.  In these cases, batch functionality
      # must be implemented manually.
      def batch_function(*methods)
        methods.each do |method_name|
          unbatched_method = "unbatched_#{method_name}"
          if method_defined?(unbatched_method)
            raise "unbatched method already defined: #{unbatched_method}"
          end
          
          arity = instance_method(method_name).arity
          args = case
          when arity < 0 then "*args"
          else Array.new(arity) {|index| "arg#{index}" }.join(", ")
          end 
          args += ", &block" if block_given?
 
          class_eval %Q{
            alias #{unbatched_method} #{method_name}
            def #{method_name}(#{args})
              batch.each do |t|
                t.#{unbatched_method}(#{args})
              end
              self
            end
          }
        end
      end
    end 
  end
end