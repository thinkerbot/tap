module Tap
  module Generator
    
    # Manifest records methods called upon it using method_missing.  These
    # actions are replayed on a generator in order (for generate) or in
    # reverse order (for destroy).
    class Manifest
      
      # Makes a new Manifest.  Method calls on self are recorded to actions.
      def initialize(actions)
        @actions = actions
      end

      # Records an action.
      def method_missing(action, *args, &block)
        @actions << [action, args, block]
      end
    end
  end
end
