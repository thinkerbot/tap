require 'tap/signals/signal'

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
      
      # Defines a signal to call a method using an argument vector. The argv
      # is sent to the method using a splat, so any method may be signaled.
      # A signature of keys may be specified to automatically generate an argv
      # from a hash; values for the keys are collected in order.
      #
      # A block may also be provided to pre-process the argv before it is sent
      # to the method; the block return is sent to the method (and so should
      # be an argv).
      def signal(sig, opts={}) # :yields: sig, argv
        signature = opts[:signature] || []
        define_signal(sig, opts) do |args|
          if args.kind_of?(Hash)
            args = signature.collect {|key| args[key] }
          end
          
          block_given? ? yield(self, args) : args
        end
      end
      
      # Defines a signal to call a method that receives a single hash as an
      # input.  A signature may be specified to automatically generate a
      # hash from an array input.
      #
      # A block may also be provided to pre-process the hash before it is sent
      # to the method; the block return is sent to the method (and so should
      # be a hash).
      def signal_hash(sig, opts={}) # :yields: sig, argh
        remainder = opts[:remainder]
        signature = opts[:signature] || []
        
        define_signal(sig, opts) do |argh|
          if argh.kind_of?(Array)
            args, argh = argh, {}
            signature.each do |key|
              argh[key] = args.shift
            end
            
            if remainder
              argh[remainder] = args
            end
          end
          
          [block_given? ? yield(self, argh) : argh]
        end
      end
      
      # Removes a signal much like remove_method removes a method.  The signal
      # constant is likewise removed unless the :remove_const option is set to
      # to true.
      def remove_signal(key, options={})
        key = key.to_s
        unless signal_registry.has_key?(key)
          raise NameError.new("#{key} is not a signal for #{self}")
        end

        options = {
          :remove_const => true
        }.merge(options)

        signal = signal_registry.delete(key)
        cache_signals(@signals != nil)

        if options[:remove_const]
          const_name = signal.to_s.split("::").pop
          remove_const(const_name) if const_defined?(const_name)
        end 
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
      def undef_signal(key, options={})
        # temporarily cache as an optimization
        sigs = signals
        key = key.to_s
        unless sigs.has_key?(key)
          raise NameError.new("#{key} is not a signal for #{self}")
        end

        options = {
          :remove_const => true
        }.merge(options)
        
        signal = sigs[key]
        signal_registry[key] = nil
        cache_signals(@signals != nil)
        
        if options[:remove_const]
          const_name = signal.to_s.split("::").pop
          remove_const(const_name) if const_defined?(const_name)
        end
      end
      
      private

      def inherited(base) # :nodoc:
       ClassMethods.initialize(base)
       super
      end
      
      def define_signal(sig, opts, &block) # :nodoc:
        # generate a subclass of signal to bind the methods
        method_name = opts.has_key?(:method_name) ? opts[:method_name] : sig
        desc = opts.has_key?(:desc) ? opts[:desc] : Lazydoc.register_caller(Lazydoc::Trailer, 2)
        klass = opts[:class] || Signal
        
        signal = klass.bind(method_name, desc, &block)
        signal_registry[sig.to_s] = signal
        
        # set the new constant, if specified
        const_name = opts.has_key?(:const_name) ? opts[:const_name] : sig.to_s.capitalize
        unless const_name.to_s.empty?
          const_set(const_name, signal)
        end
        
        signal
      end
    end
  end
end