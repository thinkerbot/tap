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
      
      def signal(sig, opts={}) # :yields: argv
        define_signal(sig, opts) do |method_name, signature, desc|
          
          Signal.bind(method_name, desc) do |args|
            if args.kind_of?(Hash)
              args = signature.collect {|key| args[key] }
            end

            block_given? ? yield(args) : args
          end
        end
      end
      
      def signal_hash(sig, opts={}) # :yields: argh
        remainder = opts[:remainder]
        define_signal(sig, opts) do |method_name, signature, desc|
          
          Signal.bind(method_name, desc) do |argh|
            if argh.kind_of?(Array)
              args, argh = argh, {}
              signature.each do |key|
                argh[key] = args.shift
              end
              
              if remainder
                argh[remainder] = args
              end
            end
            
            [block_given? ? yield(argh) : argh]
          end
        end
      end
      
      private
      
      def define_signal(sig, opts) # :nodoc:
        method_name = opts.has_key?(:method_name) ? opts[:method_name] : sig
        signature = opts[:signature] || []
        desc = opts.has_key?(:desc) ? opts[:desc] : Lazydoc.register_caller(Lazydoc::Trailer, 2)
        
        # generate a subclass of signal to bind the methods
        signal = yield(method_name, signature, desc)
        signals[sig.to_sym] = signal
        
        # set the new constant, if specified
        const_name = opts.has_key?(:const_name) ? opts[:const_name] : sig.to_s.capitalize
        const_set(const_name, signal) if const_name
        
        signal
      end
    end
  end
end