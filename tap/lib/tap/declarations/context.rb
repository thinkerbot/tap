module Tap
  module Declarations
    class Context
      include Declarations
      
      attr_reader :app
      
      def initialize(app)
        @app = app
        initialize_declare
      end
      
      def method_missing(sym, *args, &block)
        app.send(sym, *args, &block)
      end
    end
  end
end