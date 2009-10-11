require 'rap/task'

module Rap
  module Declarations
    class Context
      class << self
        def instance
          @instance ||= new
        end
      end
      
      # The declarations App
      attr_accessor :app
      
      # The base constant for all task declarations, prepended to the task name.
      attr_accessor :namespace
      
      # Tracks the current description, which will be used to document the
      # next task declaration.
      attr_accessor :desc
      
      def initialize(app=Tap::App.instance)
        app.env ||= Tap::Env.new
        @app = app
        @namespace = ""
        @desc = nil
      end
    end
  end
end