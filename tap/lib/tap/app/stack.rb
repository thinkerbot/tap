module Tap
  class App
    
    # The base of the application call stack.
    class Stack
      
      # Calls the node with the inputs:
      #
      #   node.call(*inputs)
      #
      def call(node, inputs)
        node.call(*inputs)
      end
    end
  end
end