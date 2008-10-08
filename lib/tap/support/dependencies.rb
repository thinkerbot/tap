require 'tap/support/dependency'

module Tap
  module Support
    
    # Dependencies tracks Executable dependencies and results.
    class Dependencies < Monitor
      
      def initialize
        super 
        @resolve_stack = []
      end

      def register(instance)
        synchronize do
          unless instance.kind_of?(Dependency)
            instance.extend Dependency
          end
        end
        self
      end
      
      def resolve(instance)
        synchronize do
          if @resolve_stack.include?(instance)
            raise CircularDependencyError.new(@resolve_stack)
          end
          
          # mark the results at the index to prevent
          # infinite loops with circular dependencies
          @resolve_stack.push instance
          yield
          @resolve_stack.pop
        end
        self
      end
      
      # Raised when resolve detects circular dependencies.
      class CircularDependencyError < StandardError
        def initialize(resolve_stack)
          super "circular dependency: [#{resolve_stack.join(', ')}]"
        end
      end
    end
  end
end