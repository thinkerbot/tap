module Tap
  module Signals
    
    # Signal attaches an object and allows a specific method to be triggered
    # through a standard interface.
    class Signal
      class << self
        
        # The method name signaled by this class
        attr_reader :method_name
        
        # An array of parameters extracted from a hash
        # signal to produce an argv.
        attr_reader :signature
        
        # A description of self
        attr_reader :desc
        
        def inherited(child) # :nodoc:
          super
          child.instance_variable_set(:@method_name, method_name)
          child.instance_variable_set(:@signature, signature)
          child.instance_variable_set(:@desc, nil)
        end
        
        # Produces a subclass of self that will call the specified method on
        # objects.  If a block is given it will pre-process arguments before
        # the method is called.
        def bind(method_name, signature=nil, desc="", &block)
          signal = Class.new(self)
          signal.instance_variable_set(:@method_name, method_name)
          signal.instance_variable_set(:@signature, signature)
          signal.instance_variable_set(:@desc, desc)
          signal.send(:define_method, :process, &block) if block_given?
          
          signal
        end
      end
      
      @method_name = nil
      @signature = nil
      
      # The object receiving signals through self.
      attr_reader :obj
      
      def initialize(obj)
        @obj = obj
      end
      
      # Calls obj with the method name for self, using the input arguments. 
      # Arguments are processed with process prior to the method call. If no
      # method name is set for self, the processed arguments are returned.
      def call(args=[])
        args = process(args)
        
        if method_name = self.class.method_name
          obj.send(method_name, *args)
        else
          args
        end
      end
      
      # Processes arguments before they are sent to obj.  By default process
      # simply returns args.
      def process(args)
        args
      end
    end
  end
end