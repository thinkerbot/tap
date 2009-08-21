require 'tap/signals/signal'

module Tap
  module Signals
    class Index < Signal
      
      def call(args=[])
        args = process(args)
        
        signals = obj.class.signals
        width = signals.keys.inject(0) do |max, key|
          max > key.length ? max : key.length
        end
        
        lines = [""]
        signals.each_pair do |key, signal|
          next if key.empty?
          
          desc = signal.desc.to_s
          desc = " # #{desc}" unless desc.empty?
          lines << "  #{key.ljust(width)}#{desc}"
        end
        
        lines.join("\n")
      end
    end
  end
end