module Tap
  module Support
    module Joins

      class Switch < Join
        def join(source, targets)
          complete(source) do |_result| 
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