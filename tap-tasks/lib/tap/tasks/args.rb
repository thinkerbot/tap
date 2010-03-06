require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Args < Tap::Task
      def process(*args)
        args
      end
    end 
  end
end