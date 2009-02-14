module Tap
  module Support
    module Joins
      
      # A Switch join allows a block to determine which output from an array
      # of outputs will receive the results of the input.
      class Switch < Join
        def join(inputs, outputs)
          inputs.each do |input|
            input.on_complete do |_result| 
              if index = yield(_result)        
                unless output = outputs[index] 
                  raise "no switch target for index: #{index}"
                end

                enq(output, _result)
              else
                input.app.aggregator.store(_result)
              end
            end
          end
        end
      end
      
    end
  end
end