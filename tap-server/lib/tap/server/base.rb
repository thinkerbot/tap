require 'rack'
require 'configurable'

module Tap
  class Server
    module Base
      include Configurable
    
      config :servers, %w[thin mongrel webrick], &c.list  # a list of preferred handlers
      config :host, 'localhost', &c.string                # the server host
      config :port, 8080, &c.integer                      # the server port
      
      attr_reader :handler
      
      # Runs self as configured, on the specified server, host, and port.  Use an
      # INT signal to interrupt.
      def run!(handler=rack_handler)
        handler.run self, :Host => host, :Port => port do |handler_instance|
          @handler = handler_instance
          trap(:INT) { stop! }
          yield if block_given?
        end
      end
    
      # Stops the server if running (ie a handler is set).  Returns true if the
      # server was stopped, and false otherwise.
      def stop!
        if @handler
          # Use thins' hard #stop! if available, otherwise just #stop
          @handler.respond_to?(:stop!) ? @handler.stop! : @handler.stop
          @handler = nil
          yield if block_given?
          false
        else
          true
        end
      end
    
      protected
    
      # Looks up and returns the first available Rack::Handler as listed in the
      # servers configuration. (Note rack_handler returns a handler class, not
      # an instance).  Adapted from Sinatra.detect_rack_handler
      def rack_handler # :nodoc:
        servers.each do |server_name|
          begin
            return Rack::Handler.get(server_name)
          rescue LoadError
          rescue NameError
          end
        end
        raise "Server handler (#{servers.join(',')}) not found."
      end
    end
  end
end