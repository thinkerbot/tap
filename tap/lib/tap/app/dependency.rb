module Tap
  class App
    
    # Constrains an Node to only execute once as a dependency.  Dependencies
    # cannot take inputs and track their result.
    #
    # === Dependency API
    #
    # Tap::App requires Dependencies respond to the following methods:
    #
    #   call:: called to resolve self
    #   reset:: resets self
    #   result:: the result of self after resolution
    #
    # Dependency is designed to add this API to any object responding to
    # call.  Dependency makes the object only resolve once unless reset,
    # but of there is some latitude here.  Duck-typed dependencies could
    # never reset (even after reset), or they could resolve every time
    # they are called.
    module Dependency
      
      # The result of self, set by call.
      attr_reader :result

      # Interns a new dependency by extending the block with Dependency. 
      def self.intern(&block)
        block.extend self
      end
      
      def self.extended(node) # :nodoc:
        node.reset
      end
      
      # Returns true if obj satisfies the Dependency API (node only the
      # existence of the required methods are checked).
      def self.dependency?(obj)
        obj.respond_to?(:call) && 
        obj.respond_to?(:result) && 
        obj.respond_to?(:reset)
      end
      
      # Extends obj with Dependency unless obj already satisfies the
      # Dependency API.  Returns obj.
      def self.new(obj)
        unless Dependency.dependency?(obj)
          obj.extend Dependency
        end
        obj
      end
      
      # Conditional call to the super call; only calls once.  Note that call
      # does not take any inputs, and neither should the super call.
      #
      # Returns result.
      def call
        unless @resolved
          @resolved = true
          @result = super
        end
        result
      end
      
      # Resets self so call will call again.  Also sets result to nil.
      def reset
        @resolved = false
        @result = nil
      end
    end
  end
end