require 'tap/app'

module Tap
  module Test
    
    # Sets up and tears down Tap::App.instance and Tap::Env.instance.  This
    # prevents tests that modify either from inadvertently conflicting with
    # one another.
    module TapTest
      
      # The test specific app
      attr_reader :app
      
      # The test specific env
      attr_reader :env

      def setup
        super
        @env = Tap::Env.instance = Tap::Env.new(:gems => :none)
        @app = Tap::App.instance = Tap::App.new(:debug => true, :quiet => true, :env => @env)
        @env.activate
      end

      def teardown
        @env.deactivate
        Tap::Env.instance = nil
        Tap::App.instance = nil
        super
      end
    end
  end
end