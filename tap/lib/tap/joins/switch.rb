module Tap
  module Joins
    
    # ::join
    # A Switch join allows a block to determine which output from an array
    # of outputs will receive the results of the input.
    class Switch < Join
      
      attr_accessor :selector
      
      def initialize(config={}, app=Tap::App.instance, &block)
        super(config, app)
        @selector = block
      end
      
      # Creates a join that passes the results of each input to each output.
      def join(inputs, outputs, &block)
        @selector = block
        super(inputs, outputs)
      end

      def call(result)
        index = selector.call(result)
        
        unless index && output = outputs[index] 
          raise "no switch target for result: #{result}"
        end

        enq(output, result)
      end
    end
  end
end