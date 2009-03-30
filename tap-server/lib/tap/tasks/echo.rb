module Tap
  module Tasks
    
    # ::manifest
    class Echo < Tap::Task
      def process(*args)
        args = args.flatten
        args << name
        log name, args.inspect
        args
      end
    end
  end
end