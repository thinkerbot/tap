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
      
      def each_signal(io)
        offset = -1 * ($/.length + 1)

        carryover = nil
        io.each_line do |line|
          if line[offset] == ?\\
            carryover ||= []
            carryover << line[0, line.length + offset]
            carryover << $/
            next
          end

          if carryover
            carryover << line
            line = carryover.join
            carryover = nil
          end

          sig, *args = shellsplit(line)
          yield(sig, args) if sig
        end
      end
    end
  end
end