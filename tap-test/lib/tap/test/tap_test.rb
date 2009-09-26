require 'tap/app'

module Tap
  module Test
    
    # Sets up and tears down Tap::App.instance.  This prevents tests that modify
    # either from inadvertently conflicting with one another.
    module TapTest
      
      # The test specific app
      attr_reader :app
      
      def setup
        super
        env = Tap::Env.new(:gems => :none)
        Tap::App.instance = @app ||= Tap::App.new(:debug => true, :quiet => true, :env => env)
      end

      def teardown
        Tap::App.instance = nil
        super
      end
    end
  end
end