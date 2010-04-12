module Tap
  module Declarations
    class Context
      include Declarations
      include Tap::Utils
      
      attr_reader :app
      
      def initialize(app, ns=nil)
        @app = app
        initialize_declare
        namespace(ns)
      end
      
      def method_missing(sym, *args, &block)
        app.send(sym, *args, &block)
      end
    end
  end
end