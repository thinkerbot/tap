require 'tap/join'

module Tap
  module Joins
    
    # :startdoc::join collects results before the join
    #
    # Gates a series of results before dispatching them them to the join
    # outputs.  Doing so requires a little trick.  A Gate join enques
    # itself to app the first time it is called, and then collects results
    # until it gets run.  When app runs the join, the results are dispatched.
    #
    class Gate < Join
      
      # An array of results collected thusfar.
      attr_reader :results
      
      config :limit, nil, &c.integer_or_nil   # Pass results after limit
      
      def initialize(config={}, app=Tap::App.instance)
        super
        @results = nil
      end
      
      def call(result)
        if @results
          # Results are set, so self is already enqued and collecting
          # results.  If the input is the collection, then it's time
          # to dispatch the results and reset.  Otherwise, just
          # collect the input and wait.
          
          if result == @results
            @results = nil
            super(result)
          else
            @results << result
            
            if limit && @results.length >= limit
              super(@results.dup)
              @results.clear
            end
          end
          
        else
          # No results are set, so this is a first call and self is
          # not enqued.  Setup the collection.
          
          @results = [result]
          app.enq(self, @results)
        end
        
        self
      end
    end
  end
end