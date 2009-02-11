module Tap
  module Support
    module Joins
      
      # A Switch join allows a block to determine which target from
      # set of targets will receive the results of the source.
      class Switch < Join
        def join(source, targets)
          source.on_complete do |_result| 
            if index = yield(_result)        
              unless target = targets[index] 
                raise "no switch target for index: #{index}"
              end

              enq(target, _result)
            else
              source.app.aggregator.store(_result)
            end
          end
        end
      end
      
    end
  end
end