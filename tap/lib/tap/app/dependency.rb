module Tap
  class App
    
    # Constrains an Node to only execute once as a dependency.  Dependencies
    # cannot take inputs and track their audited result.
    module Dependency
      
      # The result of self
      attr_accessor :result
      
      def self.extended(base) # :nodoc:
        base.instance_variable_set(:@result, nil)
      end
      
      # Conditional call; only calls if resolved? is false (thus assuring
      # self will only be executed once).  Note that call does not take
      # any inputs, and neither should the superclass call.
      #
      # Returns result.
      def call
        @result = super unless resolved?
        result
      end
      
      # Alias for call.
      def resolve
        call
      end
      
      # True if _result is non-nil.
      def resolved?
        @result != nil
      end
      
      # Resets the dependency by setting _result to nil.
      def reset
        @result = nil
      end
    end
  end
end