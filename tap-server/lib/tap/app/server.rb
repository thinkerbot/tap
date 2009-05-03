require 'tap'
require 'tap/controller'
require 'tap/server/base'

module Tap
  class App
    class Server < Tap::Controller
      include Tap::Server::Base
      
      # 
      set :define_action, false
      
      attr_reader :app
      
      def initialize(config={}, app=Tap::App.new)
        @app = app
        initialize_config(config)
        super()
      end
      
      def call(env)
        super(env)
      rescue ServerError
        $!.response
      rescue Exception
        ServerError.response($!)
      end
      
      set :define_action, true
      
      def index
        "goodnight moon"
      end
    end
  end
end