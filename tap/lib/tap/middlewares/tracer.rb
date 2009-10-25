require 'tap/middleware'

module Tap
  module Middlewares
    class Tracer < Middleware
      attr_reader :stack
      attr_reader :results
      attr_reader :runlist
      
      def initialize(stack)
        @stack = stack
        @results = {}
        @runlist = []
      end
      
      def call(node, inputs=[])
        runlist << node
        result = stack.call(node, inputs)
        (results[node] ||= []) << result
        result
      end
    end
  end
end