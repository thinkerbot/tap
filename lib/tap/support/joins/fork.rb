module Tap
  module Support
    module Joins
      
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

    end
  end
end