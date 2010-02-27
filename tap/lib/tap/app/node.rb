module Tap
  class App
    class Node
      class << self
        # Interns a new node by extending the block with Node. 
        def intern(app=Tap::App.instance, &block)
          new(block, app)
        end
      end
      
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
      
      # Sets the block as a join for self.
      def on_complete(&block) # :yields: result
        joins << block if block
        self
      end
    end
  end
end
