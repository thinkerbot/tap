require 'tap/task'
require 'tap/parser'

module Tap
  module Tasks
    # :startdoc::task
    class Sig < Tap::Task
      def process(*args)
        app.call Parser.parse!(args)
      end
    end
  end
end
