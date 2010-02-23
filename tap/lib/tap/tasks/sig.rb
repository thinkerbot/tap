require 'tap/task'
require 'tap/parser'

module Tap
  module Tasks
    # :startdoc::task
    class Sig < Tap::Task
      config :bind, nil
      
      def process(*args)
        sig = bind || args.shift
        app.call('sig' => sig, 'args' => args)
      end
    end
  end
end
