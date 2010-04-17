require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task sleep
    #
    # Sleeps for the specified duration.
    class Sleep < Tap::Task 
      config :duration, 1, &c.numeric  # sleep duration (ms)
      
      def call(input)
        sleep duration
        super
      end
    end 
  end
end