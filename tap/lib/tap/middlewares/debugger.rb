require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware
    class Debugger < Middleware
      module Utils
        module_function
        
        def arity_ok?(arity, n)
          n == arity || (arity < 0 && (-1-n) <= arity)
        end
      end
      
      include Utils
      
      def call(node, inputs=[])
        check_signature(node, inputs)
        super
      end
      
      def check_signature(node, inputs)
        n = inputs.length
        
        call_arity = node.method(:call).arity
        unless arity_ok?(call_arity, n)
          raise InvalidSignatureError.new(node, inputs, :call, call_arity)
        end
        
        if node.kind_of?(Task)
          process_arity = node.method(:process).arity
          unless arity_ok?(process_arity, n)
            raise InvalidSignatureError.new(node, inputs, :process, process_arity)
          end
        end
        
        if node.kind_of?(Intern)
          process_block_arity = node.process_block
          unless arity_ok?(process_block_arity, n)
            raise InvalidSignatureError.new(node, inputs, :process_block, process_block_arity)
          end
        end
        
      end
      
      class InvalidSignatureError < StandardError
        def initialize(node, inputs, method, arity)
          lines = []
          lines << "Invalid Signature (#{method}): #{node.class}"
          lines << "Expected #{arity} input but was given #{inputs.length}" 
          super(lines.join("\n"))
        end
      end
    end
  end
end