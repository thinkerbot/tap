require 'tap/signal'

module Tap
  module Signals
    module ClassMethods
      SIGNALS_CLASS = Configurable::ClassMethods::CONFIGURATIONS_CLASS
      
      # A hash of (key, Signal) pairs defining signals available to the class.
      attr_reader :signal_registry
      
      def self.initialize(base)
        unless base.instance_variable_defined?(:@signal_registry)
          base.instance_variable_set(:@signal_registry, SIGNALS_CLASS.new)
        end
        
        unless base.instance_variable_defined?(:@signals)
          base.instance_variable_set(:@signals, nil)
        end
        
        unless base.instance_variable_defined?(:@use_signal_constants)
          base.instance_variable_set(:@use_signal_constants, true)
        end
      end
      
      # A hash of (key, Signal) pairs representing all signals defined on this
      # class or inherited from ancestors.  The signals hash is generated on
      # each call to ensure it accurately reflects any signals added on
      # ancestors.  This slows down signal calls through instance.signal.
      #
      # Call cache_signals after all signals have been declared in order
      # to prevent regeneration of signals and to significantly improve
      # performance.
      def signals
        return @signals if @signals

        signals = SIGNALS_CLASS.new
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.signal_registry.each_pair do |key, value|
            if value.nil?
              signals.delete(key)
            else
              signals[key] = value
            end
          end
        end

        signals
      end

      # Caches the signals hash so as to improve peformance.  Call with on set to
      # false to turn off caching.
      def cache_signals(on=true)
        @signals = nil
        @signals = self.signals if on
      end
      
      protected
      
      def use_signal_constants(input=true)
        @use_signal_constants = input
      end
      
      # Defines a signal to call a method using an argument vector. The argv
      # is sent to the method using a splat, so any method may be signaled.
      # A signature of keys may be specified to automatically generate an argv
      # from a hash; values for the keys are collected in order.
      #
      # A block may also be provided to pre-process the argv before it is sent
      # to the method; the block return is sent to the method (and so should
      # be an argv).
      def signal(sig, opts={}, &block) # :yields: sig, argv
        signature = opts[:signature] || []
        remainder = opts[:remainder] || false
        opts[:caller_index] ||= 2
        
        define_signal(sig, opts) do |args|
          argv = convert_to_array(args, signature, remainder)
          block ? block.call(self, argv) : argv
        end
      end
      
      # Defines a signal to call a method that receives a single hash as an
      # input.  A signature may be specified to automatically generate a
      # hash from an array input.
      #
      # A block may also be provided to pre-process the hash before it is sent
      # to the method; the block return is sent to the method (and so should
      # be a hash).
      def signal_hash(sig, opts={}, &block) # :yields: sig, argh
        signature = opts[:signature] || []
        remainder = opts[:remainder]
        opts[:caller_index] ||= 2
        
        define_signal(sig, opts) do |args|
          argh = convert_to_hash(args, signature, remainder)
          [block ? block.call(self, argh) : argh]
        end
      end
      
      def define_signal(sig, opts=nil, &block) # :yields: args
        unless opts.kind_of?(Hash)
          opts = {:class => opts, :bind => false}
        end
        
        # generate a subclass of signal
        klass = opts[:class] || Signal
        signal = Class.new(klass)
        
        # bind the new signal
        method_name = opts.has_key?(:bind) ? opts[:bind] : sig
        if method_name
          signal.send(:define_method, :call) do |args|
            args = process(args)
            obj.send(method_name, *args, &self.block)
          end
        end
        
        if block_given?
          signal.send(:define_method, :process, &block)
        end
        
        if signal.respond_to?(:desc=)
          caller_index = opts[:caller_index] || 1
          signal.desc ||= Lazydoc.register_caller(Lazydoc::Trailer, caller_index)
        end
        
        register_signal(sig, signal, opts)
      end
      
      # Removes a signal much like remove_method removes a method.  The signal
      # constant is likewise removed unless the :remove_const option is set to
      # to true.
      def remove_signal(sig, opts={})
        sig = sig.to_s
        unless signal_registry.has_key?(sig)
          raise NameError.new("#{sig} is not a signal for #{self}")
        end

        unregister_signal(sig, opts)
      end

      # Undefines a signal much like undef_method undefines a method.  The signal
      # constant is likewise removed unless the :remove_const option is set to
      # to true.
      #
      # ==== Implementation Note
      #
      # Signals are undefined by setting the key to nil in the registry. Deleting
      # the signal is not sufficient because the registry needs to convey to self
      # and subclasses to not inherit the signal from ancestors.
      #
      # This is unlike remove_signal where the signal is simply deleted from
      # the signal_registry.
      #
      def undef_signal(sig, opts={})
        # temporarily cache as an optimization
        signals_cache = signals
        sig = sig.to_s
        unless signals_cache.has_key?(sig)
          raise NameError.new("#{sig} is not a signal for #{self}")
        end
        
        unregister_signal(sig, opts)
        signal_registry[sig] = nil
        signals_cache[sig]
      end
      
      private
      
      def inherited(base) # :nodoc:
        ClassMethods.initialize(base)
        
        unless base.instance_variable_defined?(:@use_signal_constants)
          base.instance_variable_set(:@use_signal_constants, true)
        end
        
        super
      end
      
      def register_signal(sig, signal, opts={}) # :nodoc:
        signal_registry[sig.to_s] = signal
        cache_signals(@signals != nil)
        
        # set the new constant, if specified
        if @use_signal_constants
          const_name = opts.has_key?(:const_name) ? opts[:const_name] : sig.to_s.capitalize
          const_name = const_name.to_s
          
          if const_name =~ /\A[A-Z]\w*\z/
            unless const_defined?(const_name) && const_get(const_name) == signal
              const_set(const_name, signal)
            end
          end
        end
        
        signal
      end
      
      def unregister_signal(sig, opts={}) # :nodoc:
        signal = signal_registry.delete(sig.to_s)
        
        remove_const = opts.has_key?(:remove_const) ? opts[:remove_const] : true
        if @use_signal_constants && remove_const
          const_name = signal.to_s.split("::").pop.to_s
          if const_name =~ /\A[A-Z]\w*\z/ && const_defined?(const_name)
            remove_const(const_name)
          end
        end
        
        cache_signals(@signals != nil)
        signal
      end
    end
  end
end