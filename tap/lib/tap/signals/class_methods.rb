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
      
      def signal(sig, opts={}) # :yields: sig, argv
        define_signal(sig, opts) do |klass, method_name, signature, desc|
          
          klass.bind(method_name, desc) do |args|
            if args.kind_of?(Hash)
              args = signature.collect {|key| args[key] }
            end

            block_given? ? yield(self, args) : args
          end
        end
      end
      
      def signal_hash(sig, opts={}) # :yields: sig, argh
        remainder = opts[:remainder]
        define_signal(sig, opts) do |klass, method_name, signature, desc|
          
          klass.bind(method_name, desc) do |argh|
            if argh.kind_of?(Array)
              args, argh = argh, {}
              signature.each do |key|
                argh[key] = args.shift
              end
              
              if remainder
                argh[remainder] = args
              end
            end
            
            [block_given? ? yield(sig, argh) : argh]
          end
        end
      end
      
      private
      
      # a helper to initialize signals for the first time,
      # mainly implemented as a hook for OrderedHashPatch
      def initialize_signals
        @signals ||= {}
      end
      
      def define_signal(sig, opts) # :nodoc:
        method_name = opts.has_key?(:method_name) ? opts[:method_name] : sig
        signature = opts[:signature] || []
        desc = opts.has_key?(:desc) ? opts[:desc] : Lazydoc.register_caller(Lazydoc::Trailer, 2)
        klass = opts[:class] || Signal
        
        # generate a subclass of signal to bind the methods
        signal = yield(klass, method_name, signature, desc)
        signals[sig.to_s] = signal
        
        # set the new constant, if specified
        const_name = opts.has_key?(:const_name) ? opts[:const_name].to_s : sig.to_s.capitalize
        const_set(const_name, signal) if const_name && !const_name.empty?
        
        signal
      end
    end
    
    module ClassMethods
      undef_method :initialize_signals

      # applies OrderedHashPatch
      def initialize_signals # :nodoc:
        @signals ||= Configurable::OrderedHashPatch.new
      end
    end if RUBY_VERSION < '1.9'
  end
end