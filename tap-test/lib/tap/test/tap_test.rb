module Tap
  module Test
    module TapTest
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