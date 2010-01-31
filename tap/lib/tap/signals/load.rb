require 'tap/signals'
require 'tap/utils'

module Tap
  module Signals
    class Load < Signal
      include Utils
      
      def call(args)
        process(*args)
      end
      
      def process(path, dir=Dir.pwd)
        path = File.expand_path(path, dir)
        return obj unless File.exists?(path)
        
        Dir.chdir(File.dirname(path)) do 
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