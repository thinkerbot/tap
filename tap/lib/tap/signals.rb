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
    def signal(sig, &block)
      sig = sig.to_s
      unless signal = self.class.signals[sig]
        raise "unknown signal: #{sig} (#{self.class})"
      end
      
      signal.new(self, &block)
    end
    
    def signal?(sig)
      sig = sig.to_s
      self.class.signals.has_key?(sig.to_s)
    end
    
    def sig(signal)
      signal = signal.class
      self.class.signals.each_pair do |sig, value|
        return sig if value == signal
      end
      nil
    end
  end
end

