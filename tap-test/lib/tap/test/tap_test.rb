require 'tap/app'

module Tap
  module Test
    
    module TapTest
      
      # The test specific app
      attr_reader :app
      
      def setup
        super
        Tap::App.instance = @app = Tap::App.new(:debug => true)
      end
      
      def teardown
        Tap::App.instance = nil
        super
      end
      
      def signal(sig, args=[], &block)
        app.call({'sig' => sig, 'args' => args}, &block)
      end
    end
  end
end