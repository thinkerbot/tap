require 'tap/signals'
require 'tap/parser'

module Tap
  module Signals
    class Load < Signal
      
      def call(args)
        process(*args)
        
      end
      
      def process(path, dir=Dir.pwd)
        path = File.expand_path(path, dir)
        
        File.open(path) do |io|
          io.each_line do |line|
            sig, *args = Parser.shellsplit(line)
            obj.signal(sig).call(args) if sig
          end
        end if File.exists?(path)
        
        obj
      end
    end
  end
end