require 'tap/task'

module Tap
  module Tasks
    class Signal < Tap::Task
      
      config(:sig, nil, :short => :s)
      
      def process(*args)
        app.signal(sig).call(args)
      end
    end
  end
end