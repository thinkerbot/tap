module Tap
  module Support
    
    # Constrains an Executable to only _execute once, and provides several
    # methods making the Executable behave like a Dependency.
    module Dependency
      
      # The audited result of self
      attr_accessor :_result
      
      def self.extended(base) # :nodoc:
        base.instance_variable_set(:@_result, nil)
      end
      
      # Conditional _execute; only calls method_name if
      # resolved? is false (thus assuring self will only
      # be executed once).
      #
      # Returns _result.
      def _execute(*args)
        app.dependencies.resolve(self) do
          @_result = super
        end unless resolved?
        _result
      end
      
      # Alias for _execute().
      def resolve
        _execute
      end
      
      # True if _result is non-nil.
      def resolved?
        @_result != nil
      end
      
      # Resets the dependency by setting _result to nil.
      def reset
        @_result = nil
      end
      
    end
  end
end