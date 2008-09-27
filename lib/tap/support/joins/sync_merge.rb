module Tap
  module Support
    module Joins
      
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
              src = _result._current_source

              source_index = indicies[src]
              (combinations[src] ||= []).each do |combination|
                if combination[source_index] != nil
                  raise "sync_merge collision... already got a result for #{src}"
                end

                combination[source_index] = _result
                unless combination.include?(nil)
                  # merge the source audits
                  _merge_result = Support::Audit.merge(*combination)

                  yield(_merge_result) if block_given?
                  enq(target, _merge_result)

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