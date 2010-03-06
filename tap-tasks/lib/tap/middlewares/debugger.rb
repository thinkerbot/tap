require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware the default debugger
    class Debugger < Middleware
      module Utils
        module_function
        
        def arity_ok?(arity, n)
          n == arity || (arity < 0 && (-1-n) <= arity)
        end
      end
      
      include Utils
      
      config :verbose, false, &c.flag
      config :output, $stderr, &c.io
      
      def call(node, inputs=[])
        open_io(output) do |io|
          io.puts "- #{node.class} #{summarize(inputs)}"
        end
        
        super
      end
      
      def summarize(inputs)
        unless verbose
          inputs = inputs.collect do |input|
            input.class
          end
        end
        
        inputs.inspect
      end
      
      class InvalidSignatureError < StandardError
        def initialize(node, inputs, method, arity)
          lines = []
          lines << "Invalid input signature to: #{node.class} (#{method})"
          lines << "Expected #{arity} input but was given #{inputs.length}" 
          super(lines.join("\n"))
        end
      end
    end
  end
end