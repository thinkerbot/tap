require 'monitor'
require 'tap/app/dependency'

module Tap
  class App
    
    # Dependencies tracks Executable dependencies and results, and provides
    # for thread-safe resolution of dependencies.
    class Dependencies < Monitor
      
      # Initializes a new Dependencies
      def initialize
        super 
        @resolve_stack = []
      end
      
      # Thread-safe registration of instance as a dependency.  During
      # registration, instance is extended with the Dependency module.
      # Returns self.
      def register(instance)
        synchronize do
          unless instance.kind_of?(Dependency)
            instance.extend Dependency
          end
        end
        self
      end
      
      # Thread-safe resolution of the instance.  Resolve checks for
      # circular dependencies, then yields control to the block,
      # which is responsible for the actual resolution.
      def resolve(instance)
        synchronize do
          if @resolve_stack.include?(instance)
            raise CircularDependencyError.new(@resolve_stack)
          end
          
          # mark the results at the index to prevent
          # infinite loops with circular dependencies
          @resolve_stack.push instance
          yield()
          @resolve_stack.pop
        end
        self
      end
      
      # Raised when Dependencies#resolve detects a circular dependency.
      class CircularDependencyError < StandardError
        def initialize(resolve_stack)
          super "circular dependency: [#{resolve_stack.join(', ')}]"
        end
      end
    end
  end
end