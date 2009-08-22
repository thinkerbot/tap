require 'tap/signals/class_methods'

module Tap
  
  # Signals is a module providing signaling capbilities for objects.  Signals
  # are effectively bound to methods with pre-processing that allows inputs
  # from the command line (ie an ARGV) or from interfaces like HTTP that
  # commonly produce a parameters hash.
  #
  module Signals
    def self.included(mod)
      super
      
      mod.extend ClassMethods
      mod.initialize_signals
      
      # initialize the default index signal
      mod.signals[""] = Index
    end
    
    def signal(sig)
      sig = sig.to_s
      unless signal = self.class.signals[sig]
        raise "unknown signal: #{sig} (#{self.class})"
      end
      
      signal.new(self)
    end
  end
end

