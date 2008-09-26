require 'tap/support/join'

module Tap
  module Support
    module Joins

      class Sequence < Join
        def join(source, targets)
          current_task = source
          targets.each do |next_task|
            # simply pass results from one task to the next. 
            complete(current_task) do |_result| 
              yield(_result) if block_given?
              enq(next_task, _result)
            end
            current_task = next_task
          end
        end
      end
      
      class Fork < Join
        def join(source, targets)
          complete(source) do |_result|
            targets.each do |target| 
              yield(_result) if block_given?
              enq(target, _result)
            end
          end
        end
      end
      
      class Merge < ReverseJoin
        def join(target, sources)
          sources.each do |source|
            # merging can use the existing audit trails... each distinct 
            # input is getting sent to one place (the target)
            complete(source) do |_result| 
              yield(_result) if block_given?
              enq(target, _result)
            end
          end
        end
      end
      
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
      
      class Switch < Join
        def join(source, targets)
          complete(source) do |_result| 
            if index = yield(_result)        
              unless target = targets[index] 
                raise "no switch target for index: #{index}"
              end

              enq(target, _result)
            else
              source.app.aggregator.store(_result)
            end
          end
        end
      end
      
    end
  end
end