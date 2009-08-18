require 'tap/signals/signal'

module Tap
  module Signals
    module ClassMethods

      # A hash of (key, Signal) pairs defining signals available to the class.
      attr_reader :signals
      
      def inherited(child) # :nodoc:
        super
        
        unless child.signals
          child.instance_variable_set(:@signals, signals.dup)
        end
      end
      
      def signal(sig, opts={}, &block)
        method_name = opts.has_key?(:method_name) ? opts[:method_name] : sig
        signature = opts[:signature]
        desc = opts.has_key?(:desc) ? opts[:desc] : Lazydoc.register_caller(Lazydoc::Trailer)
        
        # generate a subclass of signal to bind the methods
        signal = Signal.bind(method_name, signature, desc, &block)
        signals[sig.to_sym] = signal
        
        # set the new constant, if specified
        const_name = opts.has_key?(:const_name) ? opts[:const_name] : sig.to_s.capitalize
        const_set(const_name, signal) if const_name
        
        signal
      end

    end
  end
end