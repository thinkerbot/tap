module Tap
  module Joins
    
    # ::join
    # A Switch join allows a block to determine which output from an array
    # of outputs will receive the results of the input.
    class Switch < Join
      
      # An object responding to call that return the index of the output
      # to that receives the result.
      attr_accessor :selector
      
      def initialize(config={}, app=Tap::App.instance, &block)
        super(config, app)
        @selector = block
      end
      
      def join(inputs, outputs, &block)
        @selector = block
        super(inputs, outputs)
      end

      def call(result)
        index = selector.call(result)
        
        unless index && output = outputs[index] 
          raise SwitchError, "no switch target at index: #{index}"
        end

        dispatch(output, result)
      end
      
      # Raised by a Switch join to indicate when a switch index is out of bounds.
      class SwitchError < RuntimeError
      end
    end
  end
end