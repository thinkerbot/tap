module Tap
  module Tasks
    
    # ::manifest
    class Echo < Tap::Task
      def process
        "result #{Time.now}"
      end
    end
  end
end