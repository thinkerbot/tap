require 'tap/task'

module Tap
  module Tasks
    class Signal < Tap::Task
      def process(sig, *args)
        app.signal(sig).call(args)
      end
    end
  end
end