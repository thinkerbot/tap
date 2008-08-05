module Tap
  module Generator
    class Manifest
      def initialize(actions)
        @actions = actions
      end

      # Record an action.
      def method_missing(action, *args, &block)
        @actions << [action, args, block]
      end
    end
  end
end
