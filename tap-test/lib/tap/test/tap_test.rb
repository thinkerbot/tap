module Tap
  module Test
    
    # Simply sets up and tears down Tap::App.instance so that tests that
    # instantiate classes will not inadvertently smush over into one another.
    module TapTest
      
      # The test specific app
      attr_reader :app

      def setup
        super
        @app = Tap::App.instance = Tap::App.new(:debug => true, :quiet => true)
      end

      def teardown
        Tap::App.instance = nil
        super
      end
    end
  end
end