require 'tap/signals/module_methods'
require 'tap/signals/configure'
require 'tap/signals/help'
require 'tap/signals/load'

module Tap
  
  # Signals is a module providing signaling capbilities for objects.  Signals
  # are effectively bound to methods with pre-processing that allows inputs
  # from the command line (ie an ARGV) or from interfaces like HTTP that
  # commonly produce a parameters hash.
  #
  module Signals
    def signals
      # memoization here is tempting, but a bad idea because the signals must
      # be recalculated in case of added modules.  see cache_signals for a
      # better way.
      self.class.signals
    end
    
    def signal(sig, &block)
      sig = sig.to_s
      unless signal = signals[sig]
        raise "unknown signal: #{sig} (#{self.class})"
      end
      
      signal.new(self, &block)
    end
    
    def signal?(sig)
      sig = sig.to_s
      signals.has_key?(sig.to_s)
    end
    
    def sig(signal)
      signal = signal.class
      signals.each_pair do |sig, value|
        return sig if value == signal
      end
      nil
    end
  end
end

