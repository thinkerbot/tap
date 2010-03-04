require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Sleep < Tap::Task 
      config :duration, 1, &c.numeric
      
      def process
        sleep duration
      end
    end 
  end
end