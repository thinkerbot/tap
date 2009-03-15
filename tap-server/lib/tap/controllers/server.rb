require 'tap/controller'
require 'json/pure'

module Tap
  module Controllers
    
    # ::controller
    class Server < Tap::Controller
      set :default_layout, 'layout.erb'
  
      def index
        render 'index.erb'
      end
      
      # Returns 'pong'.
      def ping
        response['Content-Type'] = 'text/plain'
        "pong"
      end
      
      # Returns a JSON hash of public server configurations.
      def config
        response['Content-Type'] = 'application/json'
        { :uri => uri,
          :shutdown_key => shutdown_key
        }.to_json
      end
      
      # Shuts down the server.  Shutdown requires a shutdown key which
      # is setup when the server is launched.  If no shutdown key was
      # setup, shutdown does nothing and responds accordingly.
      def shutdown
        if shutdown_key && request['shutdown_key'].to_i == shutdown_key
          # wait a second to shutdown, so the response is sent out.
          Thread.new {sleep 1; server.stop! }
          "shutdown"
        else
          "you do not have permission to shutdown this server"
        end
      end
      
      protected
      
      # returns the server shutdown key.  the shutdown key is required
      # for shutdown to function, a nil shutdown key disables shutdown.
      def shutdown_key  # :nodoc:
        server.shutdown_key
      end
    end
  end
end