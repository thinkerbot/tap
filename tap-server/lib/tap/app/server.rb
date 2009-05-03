require 'tap'
require 'tap/server/base'
require 'tap/controller/base'
require 'eventmachine'

module Tap
  class App
    class Server
      include Tap::Server::Base
      include Tap::Controller::Base
      
      attr_reader :app
      
      def initialize(config={}, app=Tap::App.new)
        @server = @request = @response = nil
        @app = app
        initialize_config(config)
      end

      def actions
        [:index]
      end

      def default_action
        :index
      end
      
      def call(env)
        super(env)
      rescue ServerError
        $!.response
      rescue Exception
        ServerError.response($!)
      end
      
      ### actions ###
      
      def index
        "goodnight moon"
      end
    end
  end
end