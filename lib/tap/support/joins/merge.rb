module Tap
  module Support
    module Joins

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
      
    end
  end
end