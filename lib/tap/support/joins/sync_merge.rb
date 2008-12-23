module Tap
  module Support
    autoload(:Combinator, 'tap/support/combinator')
    
    module Joins
      
      # SyncMerge passes the collected results of the sources to the target. The
      # results will not be passed until results from all of the sources are 
      # available; results are passed in one group.  Similarly, a collision 
      # results if a single source completes twice before the group.
      class SyncMerge < ReverseJoin
        def join(target, sources)

          # a hash of (source, index) pairs where index is the
          # index of the source in a combination
          indicies = {}

          # a hash of (source, combinations) pairs where combinations
          # are combination arrays that the source participates in.
          # note that in unbatched mode, some sources may not
          # participate in any combinations.
          combinations = {}

          sets = sources.collect {|source| unbatched ? [source] : source.batch }
          Support::Combinator.new(*sets).each do |combo|
            combination = Array.new(combo.length, nil)

            combo.each do |source|
              indicies[source] ||= combo.index(source)
              (combinations[source] ||= []) << combination
            end
          end

          sources.each_with_index do |source, index|
            complete(source) do |_result|
              src = _result.key

              source_index = indicies[src]
              (combinations[src] ||= []).each do |combination|
                if combination[source_index] != nil
                  raise "sync_merge collision... already got a result for #{src}"
                end

                combination[source_index] = _result
                unless combination.include?(nil)

                  yield(*combination) if block_given?
                  enq(target, *combination)

                  # reset the group array
                  combination.collect! {|i| nil }
                end
              end
            end
          end
        end
      end

    end
  end
end