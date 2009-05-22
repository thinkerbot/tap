require 'rack'

module Tap
  class Server
    module Runner
      include Rack::Utils
      include Configurable
    
      config :servers, %w[thin mongrel webrick], {    # the preferred server handlers
        :long => :server
      }, &c.list 
    
      config :host, 'localhost', &c.string            # the server host
      config :port, 8080, &c.integer_or_nil           # the server port
    
      attr_reader :handler
    
      def initialize(config={})
        @handler = nil
        initialize_config(config)
      end
    
      def running?
        @handler != nil
      end
    
      # Runs self as configured, on the specified server, host, and port.  Use an
      # INT signal to interrupt.
      def run!(rack_app, handler=rack_handler)
        return self if running?
      
        handler.run(rack_app, :Host => host, :Port => port) do |handler_instance|
          @handler = handler_instance
          trap(:INT) { stop! }
          yield if block_given?
        end
      
        self
      end

      # Stops the server if running (ie a handler is set).
      def stop!
        if running?
          # Use thins' hard #stop! if available, otherwise just #stop
          @handler.respond_to?(:stop!) ? @handler.stop! : @handler.stop
          @handler = nil
        
          yield if block_given?
        end
      
        self
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