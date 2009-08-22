require 'tap/signals/index'

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
      
      private
      
      # a helper to initialize signals for the first time,
      # mainly implemented as a hook for OrderedHashPatch
      def initialize_signals # :nodoc:
        @signals ||= {}
      end
      
      def define_signal(sig, opts, &block) # :nodoc:
        # generate a subclass of signal to bind the methods
        method_name = opts.has_key?(:method_name) ? opts[:method_name] : sig
        desc = opts.has_key?(:desc) ? opts[:desc] : Lazydoc.register_caller(Lazydoc::Trailer, 2)
        klass = opts[:class] || Signal
        
        signal = klass.bind(method_name, desc, &block)
        signals[sig.to_s] = signal
        
        # set the new constant, if specified
        const_name = opts.has_key?(:const_name) ? opts[:const_name] : sig.to_s.capitalize
        unless const_name.to_s.empty?
          const_set(const_name, signal)
        end
        
        signal
      end
    end
    
    #--
    # This is a patch to track the order of signals as they are registered and
    # is only required for ruby versions before 1.9.  Afterwards, a regular hash
    # will do.
    module ClassMethods
      undef_method :initialize_signals

      # applies the OrderedHashPatch
      def initialize_signals # :nodoc:
        @signals ||= Configurable::OrderedHashPatch.new
      end
    end if RUBY_VERSION < '1.9'
  end
end