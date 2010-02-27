module Tap
  module Signals
    class Help < Signal
      
      def call(input)
        args = convert_to_array(input, ['sig'])
        args.empty? ? list : process(*args)
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
        
        "signals (#{obj.class})\n#{lines.join("\n")}"
      end
      
      def process(sig)
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