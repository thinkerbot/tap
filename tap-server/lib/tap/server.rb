require 'rack'
require 'tap'
require 'tap/server/data'
require 'tap/server/server_error'

module Tap
  # ::configurable
  class Server
    include Rack::Utils
    include Configurable

    config :servers, %w[thin mongrel webrick],      # the server handlers
      :long => :server, 
      &c.list 
  
    config :host, '127.0.0.1', &c.string            # the server host
    config :port, 8080, &c.integer_or_nil           # the server port
    
    # Server implements a secret for HTTP administration of the server (ex
    # remote shutdown). Under many circumstances this functionality is
    # undesirable; specify a nil secret, the default, to prevent remote
    # administration.
    config :secret, nil, &c.string_or_nil           # the admin secret
    
    config :development, false, &c.flag
    
    nest :data, Data, :type => :hidden
    
    attr_reader :app
    attr_reader :controller
    
    def initialize(config={}, app=Tap::App.current, &block)
      @handler = nil
      @controller = block
      
      @app = app
      initialize_config(config)
    end
    
    def env
      app.env
    end
    
    def bind(controller)
      if controller.kind_of?(String)
        controller = app.resolve(controller)
      end
      
      unless controller.respond_to?(:call)
        raise "invalid controller: #{controller.inspect}"
      end
      
      @controller = controller
      self
    end
    
    # Returns true if input is equal to the secret, if a secret is set. Used
    # to test if a particular request has rights to a remote administrative
    # action.
    def admin?(input)
      secret != nil && input == secret
    end
    
    def template_path(path)
      app.env.path(:views, path) {|file| File.file?(file) }
    end
    
    def module_path(path, klass)
      app.env.module_path(:views, klass.ancestors, path) {|file| File.file?(file) }
    end
    
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      # handle the request
      rack_env['tap.server'] = self
      controller.call(rack_env)
    rescue ServerError
      $!.response
    rescue Exception
      ServerError.response($!)
    end
    
    # Runs self as configured, on the specified server, host, and port.  Use an
    # INT signal to interrupt.
    def run!(handler=rack_handler)
      return self if @handler
    
      handler.run(self, :Host => host, :Port => port) do |handler|
        @handler = handler
        trap(:INT) { stop! }
        yield if block_given?
      end
    
      self
    end

    # Stops the server if running (ie a handler is set).
    def stop!
      if @handler
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