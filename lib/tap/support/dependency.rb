module Tap
  module Support
    module Dependency
      
      # The audited result of self.
      attr_accessor :_result
      
      def self.extended(base)
        base.instance_variable_set(:@_result, nil)
        base.on_complete do |_result|
          base._result = _result
        end
      end
      
      # Conditional _execute; only calls _method_name if
      # resolved? is false (thus assuring self will only
      # be executed once).
      #
      # Returns _result.
      def _execute(*args)
        app.dependencies.resolve(self) do
          super
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