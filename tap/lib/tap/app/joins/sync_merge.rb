module Tap
  class App
    module Joins
      
      # SyncMerge passes the collected results of the inputs to the outputs. The
      # results will not be passed until results from all of the inputs are 
      # available; results are passed in one group.  Similarly, a collision 
      # results if a single input completes twice before the group completes as
      # a whole.
      class SyncMerge < Join
        
        attr_reader :results
        
        def initialize(config={})
          super
          @results = nil
        end
        
        def join(inputs, outputs)
          @results = Array.new(inputs.length)
          super(inputs, outputs)
        end
        
        def call(_result)
          index = inputs.index(_result.key)
          
          unless results[index] == nil
            raise "sync_merge collision... already got a result for #{inputs[index]}"
          end
          results[index] = _result
          
          unless results.include?(nil)
            outputs.each {|output| enq(output, *results) }
            
            # reset the results array
            results.collect! {|i| nil }
          end
        end
        
      end
    end
  end
end