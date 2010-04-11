module Tap
  module Joins
    
    # :startdoc::join collects results before the join
    #
    # Similar to a synchronized merge, but collects all results regardless of
    # where they come from.  Gates enque themselves when called as a join, and
    # won't let results pass until they get run as a node.
    # 
    #   % tap load a -- load b - inspect - gate 0,1 2
    #   ["a", "b"]
    # 
    # Gates are useful in conjunction with iteration where a single task may
    # feed multiple results to a single join; in this case a sync merge doesn't
    # produce the desired behavior of collecting the results.
    # 
    #   % tap load/yaml "[1, 2, 3]" -:i inspect -:.gate inspect
    #   1
    #   2
    #   3
    #   [1, 2, 3]
    # 
    #   % tap load/yaml "[1, 2, 3]" -:i inspect -:.sync inspect
    #   1
    #   [1]
    #   2
    #   [2]
    #   3
    #   [3]
    # 
    # When a limit is specified, the gate will collect results up to the limit
    # and then pass the results.  Any leftover results are still passed at the
    # end.
    #
    #   % tap load/yaml "[1, 2, 3]" -:i inspect - inspect - gate 1 2 --limit 2
    #   1
    #   2
    #   [1, 2]
    #   3
    #   [3]
    #
    class Gate < Join
      
      # An array of results collected thusfar.
      attr_reader :results
      
      config :limit, nil, :short => :l, &c.integer_or_nil   # Pass results after limit
      
      def initialize(config={}, app=Tap::App.current)
        super
        @results = nil
      end
      
      def call(result)
        if @results
          # Results are set, so self is already enqued and collecting
          # results.  If the input is the collection, then it's time
          # to execute the results and reset.  Otherwise, just
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