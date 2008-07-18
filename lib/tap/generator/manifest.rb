require File.dirname(__FILE__) + "/../../../vendor/blank_slate"

module Tap
  module Generator
    class Manifest < BlankSlate
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
