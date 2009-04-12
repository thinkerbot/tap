module Tap
  class App
    
    # Constrains an Node to only execute once as a dependency.  Dependencies
    # cannot take inputs and track their audited result.
    module Dependency
      
      # The audited result of self
      attr_accessor :_result
      
      def self.extended(base) # :nodoc:
        base.instance_variable_set(:@_result, nil)
      end
      
      # Conditional call; only calls if resolved? is false (thus assuring
      # self will only be executed once).  Note that call does not take
      # any inputs, and neither should the superclass call.
      #
      # Returns _result.
      def call
        @_result = super unless resolved?
        _result
      end
      
      # Alias for call.
      def resolve
        call
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