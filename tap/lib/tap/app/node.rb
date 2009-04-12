require 'tap/app/join'
require 'tap/app/dependency'

module Tap
  class App
    
    # Node wraps objects to make them executable by App.
    module Node
      
      # The App calling self (set by App during execute)
      attr_accessor :app
      
      # The join called when call completes
      attr_accessor :join
      
      # An array of dependencies that will be resolved by app
      attr_reader :dependencies
      
      public
      
      # Interns a new Node by extending the block with Node. 
      def self.intern(&block)
        block.extend self
      end
      
      # Sets up required variables for extended objects.
      def self.extended(obj)
        obj.instance_variable_set(:@app, nil)
        obj.instance_variable_set(:@join, nil)
        obj.instance_variable_set(:@dependencies, [])
      end
      
      # Sets a block as the join for self.
      def on_complete(&block) # :yields: _result
        self.join = block_given? ? Join.intern(&block) : nil
        self
      end
      
      # Adds the dependencies to self.  Dependencies are resolved during
      # App#execute through resolve_dependencies.
      def depends_on(*dependencies)
        raise ArgumentError, "cannot depend on self" if dependencies.include?(self)
        
        dependencies.each do |dependency|
          unless dependency.kind_of?(Dependency)
            dependency.extend Dependency
          end
          
          unless self.dependencies.include?(dependency)
            self.dependencies << dependency
          end
        end
        
        self
      end
      
      # Resolves dependencies.
      def resolve_dependencies(resolve_stack=[])
        dependencies.each do |dependency|
          if resolve_stack.include?(dependency)
            raise CircularDependencyError.new(resolve_stack)
          end
          
          # mark the results at the index to prevent
          # infinite loops with circular dependencies
          resolve_stack.push dependency
          
          dependency.resolve_dependencies(resolve_stack)
          dependency.resolve
          
          resolve_stack.pop
        end
        
        self
      end

      # Resets dependencies so they will be re-resolved on
      # resolve_dependencies.
      def reset_dependencies
        dependencies.each {|dependency| dependency.reset }
        self
      end
      
      # Raised when Node#resolve_dependencies detects a circular dependency.
      class CircularDependencyError < StandardError
        def initialize(resolve_stack)
          super "circular dependency: [#{resolve_stack.join(', ')}]"
        end
      end
    end
  end
end
