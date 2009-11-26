require 'tap/signals'

module Tap
  module Signals
    class Help < Signal
      
      def call(args)
        argv = convert_to_array(args, ['sig'])
        argv.empty? ? list : desc(*argv)
      end
      
      def list
        signals = obj.class.signals
        width = signals.keys.collect {|key| key.length }.max
        
        lines = []
        signals.each_pair do |key, signal|
          next if key.empty?
          
          desc = signal.desc.to_s
          desc = " # #{desc}" unless desc.empty?
          lines << "  /#{key.ljust(width)}#{desc}"
        end
        
        "signals: (#{obj.class})\n#{lines.join("\n")}"
      end
      
      def desc(sig)
        clas = obj.signal(sig).class
        
        if clas.respond_to?(:desc)
          desc = clas.desc
          "#{clas} -- #{desc.to_s}\n#{desc.wrap}"
        else
          "#{clas} -- no help available"
        end
      end
    end
  end
end