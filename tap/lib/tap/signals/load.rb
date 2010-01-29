require 'tap/signals'

module Tap
  module Signals
    class Load < Signal
      
      def call(args)
        process(*args)
      end
      
      def process(path, dir=Dir.pwd)
        # parse lines
        # parse args
        # signal each to obj
        obj
      end
    end
  end
end