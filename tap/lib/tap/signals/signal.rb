module Tap
  module Signals
    class Signal
      class << self
        attr_reader :method_name
        attr_reader :signature
        attr_reader :desc
        
        def bind(method_name, signature=nil, desc="", &block)
          signal = Class.new(Signal)
          signal.instance_variable_set(:@method_name, method_name)
          signal.instance_variable_set(:@signature, signature)
          signal.instance_variable_set(:@desc, desc)
          signal.send(:define_method, :process, &block) if block_given?
          
          signal
        end
      end
      
      attr_reader :obj
      
      def initialize(obj)
        @obj = obj
      end
      
      def call(args)
        obj.send(self.class.method_name, *process(args))
      end
      
      def process(args)
        args
      end
    end
  end
end