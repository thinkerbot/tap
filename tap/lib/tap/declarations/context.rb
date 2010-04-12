module Tap
  module Declarations
    class Context
      include Declarations
      
      attr_reader :app
      
      def initialize(app)
        @app = app
        @desc = nil
        @baseclass = Tap::Task
        @namespace = Object
      end
      
      def method_missing(sym, *args, &block)
        app.send(sym, *args, &block)
      end
    end
  end
end