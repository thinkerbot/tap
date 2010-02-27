module Tap
  class App
    
    # The base of the application call stack.
    class Stack
      
      # The application using this stack.
      attr_reader :app
      
      def initialize(app)
        @app = app
      end
      
      # Checks app for termination and then calls the node with the input:
      #
      #   node.call(input)
      #
      def call(node, input)
        app.check_terminate
        node.call(input)
      end
    end
  end
end