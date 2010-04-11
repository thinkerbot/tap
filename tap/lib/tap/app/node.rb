module Tap
  class App
    class Node
      attr_reader :app
      
      attr_reader :callable
      
      # The joins called when call completes
      attr_accessor :joins
      
      # Interns a new node by extending the block with Node. 
      def initialize(callable, app=Tap::App.instance)
        @callable = callable
        @app = app
        @joins = []
      end
      
      def call(input)
        callable.call(*input)
      end
      
      def enq(*args)
        app.enq(self, args)
      end
      
      def exe(*inputs)
        app.exe(self, inputs)
      end
      
      # Sets the block as a join for self.
      def on_complete(&block) # :yields: result
        joins << block if block
        self
      end
    end
  end
end
