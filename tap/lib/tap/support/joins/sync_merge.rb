module Tap
  module Support
    module Joins
      
      # SyncMerge passes the collected results of the inputs to the outputs. The
      # results will not be passed until results from all of the inputs are 
      # available; results are passed in one group.  Similarly, a collision 
      # results if a single input completes twice before the group completes as
      # a whole.
      class SyncMerge < Join
        
        def join(inputs, outputs)
          results = Array.new(inputs.length)
          
          inputs.each do |input|
            input.on_complete do |_result|
              index = inputs.index(_result.key)
              
              unless results[index] == nil
                raise "sync_merge collision... already got a result for #{inputs[index]}"
              end
              results[index] = _result
              
              unless results.include?(nil)
                yield(*results) if block_given?
                outputs.each {|output| enq(output, *results) }
                
                # reset the results array
                results.collect! {|i| nil }
              end
            end
          end
        end
        
      end
    end
  end
end