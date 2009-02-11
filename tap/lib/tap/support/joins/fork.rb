module Tap
  module Support
    module Joins
      
      # A Fork join passes the results of source to each of the targets.
      class Fork < Join
        def join(source, targets)
          source.on_complete do |_result|
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