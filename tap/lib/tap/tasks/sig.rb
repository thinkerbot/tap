require 'tap/task'
require 'tap/parser'

module Tap
  module Tasks
    # :startdoc::task
    class Sig < Tap::Task
      def process(sig, *args)
        app.call('sig' => sig, 'args' => args)
      end
    end
  end
end
