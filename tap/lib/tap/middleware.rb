require 'tap/app'

module Tap
  class Middleware < App::Api
    class << self
      def build(spec={}, app=Tap::App.instance)
        app.use(self, spec['config'] || {})
      end
    end
    
    # The call stack.
    attr_reader :stack

    def initialize(stack, config={})
      @stack = stack
      initialize_config(config)
    end
    
    # Returns the app at the base of the stack.
    def app
      @app ||= begin
        current = stack
        until current.kind_of?(App::Stack)
          current = current.stack
        end
        current.app
      end
    end
    
    # By default call simply calls stack with the node and inputs.
    def call(node, inputs=[])
      stack.call(node, inputs)
    end
  end
end