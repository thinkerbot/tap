module Tap
  class App
    class Stack
      def call(node, inputs)
        node.call(*inputs)
      end
    end
  end
end