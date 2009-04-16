module Tap
  module Joins
    
    # ::join
    # SyncMerge passes the collected results of the inputs to the outputs. The
    # results will not be passed until results from all of the inputs are 
    # available; results are passed in one group.  Similarly, a collision 
    # results if a single input completes twice before the group completes as
    # a whole.
    class Sync < Join
            
      attr_reader :results
      
      def initialize(config={}, app=Tap::App.instance)
        super
        @results = nil
      end
      
      def reset
        @results = inputs ? Array.new(inputs.length) : nil
      end
      
      def join(inputs, outputs)
        index = 0
        @inputs = inputs.each do |input|
          input.join = Callback.new(self, index)
          index += 1
        end
        @outputs = outputs
        reset
        self
      end
      
      def call(result, index)
        unless results[index] == nil
          raise SynchronizeError, "already got a result for #{inputs[index]}"
        end
        results[index] = result
        
        unless results.include?(nil)
          outputs.each {|output| execute(output, *results) }
          reset
        end
      end
      
      class Callback
        attr_reader :join
        attr_reader :index
        
        def initialize(join, index)
          @join = join
          @index = index
        end
        
        def call(result)
          join.call(result, index)
        end
      end
      
      class SynchronizeError < RuntimeError
      end
    end
  end
end