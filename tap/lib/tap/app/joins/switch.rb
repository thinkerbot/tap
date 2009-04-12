module Tap
  class App
    module Joins
      
      # A Switch join allows a block to determine which output from an array
      # of outputs will receive the results of the input.
      class Switch < Join
        
        attr_accessor :selector
        
        def initialize(config={}, &block)
          super(config)
          @selector = block
        end
        
        # Creates a join that passes the results of each input to each output.
        def join(inputs, outputs, &block)
          @selector = block
          super(inputs, outputs)
        end

        def call(_result)
          index = selector.call(_result)
          
          unless index && output = outputs[index] 
            raise "no switch target for _result: #{_result}"
          end

          enq(output, _result)
        end
      end
      
    end
  end
end