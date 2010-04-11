require 'tap/app'
require 'tap/test/env'

module Tap
  module Test
    module TapTest
      
      # The test specific app
      attr_reader :app
      
      def setup
        super
        @app = Tap::App.new({:debug => true}, {:env => Env.new})
        @context = Tap::App.set_context(Tap::App::CURRENT => @app)
      end
      
      def teardown
        Tap::App.set_context(@context)
        super
      end
      
      def signal(sig, args=[], &block)
        app.call({'sig' => sig, 'args' => args}, &block)
      end
    end
  end
end