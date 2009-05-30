module Tap
  class App
    
    # The base of the application call stack.
    class Stack
      
      # The application using this stack.
      attr_reader :app
      
      def initialize(app)
        @app = app
      end
      
      # Checks app for termination and then calls the node with the inputs:
      #
      #   node.call(*inputs)
      #
      def call(node, inputs)
        app.check_terminate
        node.call(*inputs)
      end
    end
  end
end