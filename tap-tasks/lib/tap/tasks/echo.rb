require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task echos back arguments as a string
    #
    class Echo < Tap::Task 
      def process(*args)
        args.join(' ')
      end
    end 
  end
end