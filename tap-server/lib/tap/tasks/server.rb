require 'tap/server'

module Tap
  module Tasks
    
    # ::manifest
    class Server < Tap::Task
      
      nest(:env, Tap::Env) do |config|
        case config
        when Tap::Env then config
        else Tap::Env.new(config)
        end
      end
      
      nest_attr(:server, Tap::Server) do |config|
        @server = Tap::Server.new(env, config)
      end
      
      def process(method='get', uri="/")
        uri = URI(uri[0] == ?/ ? uri : "/#{uri}")
        uri.host ||= server.host
        uri.port ||= server.port
        
        mock = Rack::MockRequest.new(server)
        mock.request(method, uri.to_s)
      end
    end
  end
end