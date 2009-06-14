require 'configurable'

module Tap
  class Middleware
    class << self
      
      # Instantiates an instance of self and causes app to use the instance
      # as middleware.
      def parse(argv=ARGV, app=Tap::App.instance)
        parse!(argv.dup, app)
      end
      
      # Same as parse, but removes arguments destructively.
      def parse!(argv=ARGV, app=Tap::App.instance)
        opts = ConfigParser.new
        opts.separator "configurations:"
        opts.add(configurations)
        
        args = opts.parse!(argv, :add_defaults => false)
        instantiate({:config => opts.nested_config}, app)
      end
      
      # Instantiates an instance of self and causes app to use the instance
      # as middleware.
      def instantiate(argh, app=Tap::App.instance)
        app.use(self, argh[:config] || {})
      end
    end
    
    include Configurable
    
    # The call stack.
    attr_reader :stack

    def initialize(stack, config={})
      @stack = stack
      initialize_config(config)
    end
    
    # By default call simply calls stack with the node and inputs.
    def call(node, inputs=[])
      stack.call(node, inputs)
    end
  end
end