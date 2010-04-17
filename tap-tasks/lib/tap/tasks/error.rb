require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task raises an error
    #
    # Error raises a Runtime error when called.  The input specifies the
    # error message.
    #
    class Error < Tap::Task 
      def process(msg=nil)
        raise msg
      end
    end 
  end
end