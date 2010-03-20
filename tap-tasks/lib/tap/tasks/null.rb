require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task a dev/null task
    #
    # Null serves the same function as /dev/null, that is inputs directed
    # to Null go nowhere.  Null does not accept joins and will not execute
    # the default app joins.
    #
    #   % tap load/yaml '[1, 2, 3]' -: null
    #
    class Null < Tap::Task
      def process(*args)
      end
      
      def joins
        nil
      end
      
      def on_complete
        raise "cannot be participate in joins: #{self}"
      end
    end 
  end
end