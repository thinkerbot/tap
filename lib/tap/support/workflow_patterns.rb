module Tap
  module Support
    module WorkflowPatterns
      
      # Sets a sequence workflow pattern for the tasks such that the
      # completion of a task enqueues the next task with it's results.
      # Batched tasks will have the pattern set for each task in the 
      # batch.  The current audited results are yielded to the block, 
      # if given, before the next task is enqued.
      #
      # Executables may provided as well as tasks.
      def sequence(*tasks) # :yields: _result
        current_task = tasks.shift
        tasks.each do |next_task|
          # simply pass results from one task to the next.  
          current_task.on_complete do |_result| 
            yield(_result) if block_given?
            enq(next_task, _result)
          end
          current_task = next_task
        end
      end

      # Sets a fork workflow pattern for the tasks such that each of the
      # targets will be enqueued with the results of the source when the
      # source completes. Batched tasks will have the pattern set for each 
      # task in the batch.  The source audited results are yielded to the 
      # block, if given, before the targets are enqued.
      #
      # Executables may provided as well as tasks.
      def fork(source, *targets) # :yields: _result
        source.on_complete do |_result|
          targets.each do |target| 
            yield(_result) if block_given?
            enq(target, _result)
          end
        end
      end

      # Sets a merge workflow pattern for the tasks such that the results
      # of each source will be enqueued to the target when the source 
      # completes. Batched tasks will have the pattern set for each 
      # task in the batch.  The source audited results are yielded to  
      # the block, if given, before the target is enqued.
      #
      # Executables may provided as well as tasks.
      def merge(target, *sources) # :yields: _result
        sources.each do |source|
          # merging can use the existing audit trails... each distinct 
          # input is getting sent to one place (the target)
          source.on_complete do |_result| 
            yield(_result) if block_given?
            enq(target, _result)
          end
        end
      end
      
    end 
  end
end