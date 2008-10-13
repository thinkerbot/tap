module Tap
  module Support
    module Joins
      
      # A Sequence join simply pass results from one task to the next. 
      class Sequence < Join
        def join(source, targets)
          current_task = source
          targets.each do |next_task|
            complete(current_task) do |_result| 
              yield(_result) if block_given?
              enq(next_task, _result)
            end
            current_task = next_task
          end
        end
      end
      
    end
  end
end