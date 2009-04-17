module Tap
  module Joins
    
    # ::join
    # Sync works the same as Join, but passes the collected results of the inputs
    # to the outputs. The results will not be passed until results from all of
    # the inputs are available; results are passed in one group.  Similarly, a
    # collision results if a single input completes twice before the group
    # completes as a whole.
    class Sync < Join
      
      # NIL_VALUE is used to mark empty slots (nil itself cannot be used
      # because it is a valid result value).
      NIL_VALUE = Object.new
      
      # An array holding results until the batch is ready to execute.
      attr_reader :results
      
      def initialize(config={}, app=Tap::App.instance)
        super
        @results = nil
      end
      
      # Resets results.  Normally there is no reason to call this method as it
      # will shuffle the arguments being passed through self.
      def reset
        @results = inputs ? Array.new(inputs.length, NIL_VALUE) : nil
      end
      
      # A synchronized join sets a Callback as the join of each input.  The
      # callback is responsible for setting the result of each input into the
      # correct 'results' slot.
      def join(inputs, outputs)
        @inputs.each do |input|
          input.join = nil
        end if @inputs

        @inputs = inputs

        index = 0
        inputs.each do |input|
          input.join = Callback.new(self, index)
          index += 1
        end if inputs
        reset
        
        @outputs = outputs
        self
      end
      
      # Call is called by a Callback and stores the result at the specified
      # index in results.  If the results have all been set, then they are
      # sent to each output.
      def call(result, index)
        if result == NIL_VALUE
          raise "NIL_VALUE cannot be passed as a result"
        end
        
        unless results[index] == NIL_VALUE
          raise SynchronizeError, "already got a result for: #{inputs[index]}"
        end
        results[index] = result
        
        unless results.include?(NIL_VALUE)
          outputs.each {|output| dispatch(output, results) }
          reset
        end
      end
      
      class Callback
        
        # A backreference to the parent Sync join.
        attr_reader :join
        
        # The results index where result should be stored.
        attr_reader :index
        
        def initialize(join, index)
          @join = join
          @index = index
        end
        
        # Calls back to join to store the result at index.
        def call(result)
          join.call(result, index)
        end
      end
      
      # Raised by a Sync join to indicate when an input returns twice before
      # the group is ready to execute.
      class SynchronizeError < RuntimeError
      end
    end
  end
end