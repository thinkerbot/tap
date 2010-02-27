require 'tap/utils'

module Tap
  module Signals
    class Load < Signal
      include Utils
      
      def call(args)
        args.each {|path| process(path) }
        obj
      end
      
      def process(path)
        if File.exists?(path)
          File.open(path) do |io|
            each_signal(io) do |sig, args|
              obj.signal(sig).call(args)
            end
          end
        end
        
        obj
      end
    end
  end
end