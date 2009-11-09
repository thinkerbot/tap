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
        Tap::App.instance = @app = Tap::App.new(app_config)
      end
      
      def env_config
        {:gems => :none, :root => @method_root || Dir.pwd}
      end
      
      def app_config
        {:debug => true, :quiet => true, :env => Tap::Env.new(env_config)}
      end
      
      def teardown
        Tap::App.instance = nil
        super
      end
    end
  end
end