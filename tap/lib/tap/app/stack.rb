module Tap
  class App
    
    # The base of the application call stack.
    class Stack
      
      # The application using this stack.
      attr_reader :app
      
      def initialize(app)
        @app = app
      end
      
      # Checks app for termination and then calls the task with the input:
      #
      #   task.call(input)
      #
      def call(task, input)
        app.check_terminate
        task.call(input)
      end
    end
  end
end