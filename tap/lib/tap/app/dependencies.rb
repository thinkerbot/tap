require 'monitor'
require 'tap/app/dependency'

module Tap
  class App
    
    # Dependencies tracks application-wide dependencies and provides an
    # environment to resolve dependencies.
    class Dependencies < Monitor
      
      # Initializes a new Dependencies
      def initialize
        super
        @registry = {}
        @stack = []
      end
      
      # Registers a node with self.  The node is registered as a dependency
      # if necessary (see Dependency.register).
      def []=(key, node)
        synchronize do
          @registry[key] = Dependency.register(node)
        end
      end
      
      # Retrieves a registered node.
      def [](key)
        synchronize do
          @registry[key]
        end
      end
      
      # The number of key-node pairs registered with self.
      def size
        synchronize do
          @registry.size
        end
      end
      
      # True if size == 0
      def empty?
        synchronize { size == 0 }
      end
      
      # Returns true if the key has a registered node.
      def has_key?(key)
        synchronize do
          @registry.has_key?(key)
        end
      end
      
      # Yields each key-node pair to the block.
      def each_pair
        synchronize do
          @registry.each_pair do |key, node|
            yield(key, node)
          end
        end
      end
      
      # Resolve checks for circular dependencies, and then yields control to the
      # block.  The block is responsible for the actual resolution.
      def resolve(node)
        synchronize do
          if @stack.include?(node)
            @stack.push node
            raise CircularDependencyError.new(@stack)
          end
          
          # mark the results at the index to prevent
          # infinite loops with circular dependencies
          @stack.push node
          yield()
          @stack.pop
        end
        self
      end
      
      # Raised when Dependencies#resolve detects a circular dependency.
      class CircularDependencyError < StandardError
        def initialize(stack)
          super "circular dependency: [#{stack.join(', ')}]"
        end
      end
    end
  end
end