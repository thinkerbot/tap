module Tap
  module Support
    
    # Dependencies tracks Executable dependencies and results.
    class Dependencies
      
      # An array of registered [instance, argv] pairs.
      attr_reader :registry
      
      # An array of results matching the registry, produced 
      # during dependency resolution by instance._execute(*argv).
      attr_reader :results
      
      def initialize
        @registry = []
        @results = []
        @resolve_stack = []
      end
      
      # Clears all registered dependencies and results.  
      def clear
        registry.clear
        results.clear
        @resolve_stack.clear
      end
      
      # Returns the index of the [instance, argv] pair in self,
      # or nil if the pair is not registered,
      def index(instance, argv=[])
        registry.each_with_index do |entry, index|
          return index if entry[0] == instance && entry[1] == argv
        end
        nil
      end
      
      # Registers an [instance, argv] pair with self and returns the index of 
      # the pair in the registry; returns the index of a matching pair in the 
      # registry if the instance and argv are already registered.
      def register(instance, argv=[])
        if existing = index(instance, argv)
          return existing 
        end

        registry << [instance, argv]
        registry.length - 1
      end
      
      # Resolves the instance-argv pairs at the specified indicies by calling 
      # instance._execute(*argv).  Results are collected in results; a pair is 
      # only resolved if an existing result does not exist.  An error is
      # raised if circular dependencies are detected.  Returns self.
      def resolve(indicies)
        indicies.each do |index|
          next if resolved?(index)
          
          if @resolve_stack.include?(index)
            raise CircularDependencyError.new(@resolve_stack)
          end

          # mark the results at the index to prevent
          # infinite loops with circular dependencies
          @resolve_stack.push index

          instance, inputs = registry[index]
          results[index] = instance._execute(*inputs)
          
          @resolve_stack.pop
        end
        self
      end
      
      # Returns true if the results at the specified index are non-nil (note 
      # that Dependencies expects instance-argv pairs to resolve to an Audit; 
      # the current value of the Audit may, of course, be nil).
      def resolved?(index)
        results[index] != nil
      end
      
      # Sets the results at specified indicies to nil so that their 
      # instance-argv pairs will re-execute on resolve. Returns self.
      def reset(indicies)
        indicies.each {|index| results[index] = nil }
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