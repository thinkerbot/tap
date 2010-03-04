require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Sig < Tap::Task 
      def process(obj, sig, *args)
        app.route(obj, sig).call(args)
      end
    end 
  end
end