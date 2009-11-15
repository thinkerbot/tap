module Tap
  module Signals
    
    # Signal attaches an object and allows a specific method to be triggered
    # through a standard interface.
    class Signal
      class << self
        
        # A description of self
        attr_reader :desc
        
        def inherited(child) # :nodoc:
          super
          child.instance_variable_set(:@desc, nil)
        end
        
        # Produces a subclass of self that will call the specified method on
        # objects.  If a block is given it will pre-process arguments before
        # the method is called.
        def bind(method_name=nil, desc="", &block)
          signal = Class.new(self)
          signal.instance_variable_set(:@desc, desc)
          
          if method_name
            signal.send(:define_method, :call) do |args|
              args = process(args)
              obj.send(method_name, *args, &self.block)
            end
          end
          
          if block_given?
            signal.send(:define_method, :process, &block)
          end
          
          signal
        end
      end
      @desc = nil
      
      # The object receiving signals through self.
      attr_reader :obj
      
      attr_reader :block
      
      def initialize(obj, &block)
        @obj = obj
        @block = block
      end
      
      # Calls process with the input args and returns the result.  This method
      # is a hook for subclasses.
      def call(args)
        process(args)
      end
      
      # Simply returns the input args.  This method is a hook for subclasses.
      def process(args)
        args
      end
    end
  end
end