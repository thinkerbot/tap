module Tap
  module Support
    module Joins
      
      # SyncMerge passes the collected results of the sources to the target. The
      # results will not be passed until results from all of the sources are 
      # available; results are passed in one group.  Similarly, a collision 
      # results if a single source completes twice before the group.
      class SyncMerge < ReverseJoin
        
        def join(sources, target)
          results = Array.new(sources.length)
          sources.each do |source|
            source.on_complete do |_result|
              index = sources.index(_result.key)
              
              unless results[index] == nil
                raise "sync_merge collision... already got a result for #{sources[index]}"
              end
              results[index] = _result
              
              unless results.include?(nil)
                yield(*results) if block_given?
                enq(target, *results)
                
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