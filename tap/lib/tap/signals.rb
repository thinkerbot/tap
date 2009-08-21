require 'tap/signals/class_methods'

module Tap
  
  # Signals is a module providing signaling capbilities for objects.  Signals
  # are effectively bound to methods with pre-processing that allows inputs
  # from the command line (ie an ARGV) or from interfaces like HTTP that
  # commonly produce a parameters hash.
  #
  #
  
  module Signals
    def self.included(mod)
      mod.extend ClassMethods
      mod.initialize_signals
      mod.signal("", :class => Index)
      super
    end
    
    # To mount as a controller (provided in utils):
    #
    #   lambda do |env|
    #     obj.signal(env.path_info, env.query)
    #   end
    #
    # 
    # Should handle array args or hash.
    def signal(sig, args=[])
      sig = sig.to_s
      unless signal = self.class.signals[sig]
        raise "unknown signal: #{sig} (#{self.class})"
      end
      
      signal.new(self).call(args)
    end
  end
end

