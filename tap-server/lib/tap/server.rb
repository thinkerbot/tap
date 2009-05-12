require 'rack'
require 'tap'
require 'tap/server/persistence'
require 'tap/server/server_error'

module Tap
  
  # :::-
  # Server is a Rack application that dispatches calls to other Rack apps, most
  # commonly a Tap::Controller.
  #
  # == Routes
  #
  # Routing is fixed and very simple:
  #
  #   /:controller/path/to/resource
  #
  # Server dispatches the request to the controller keyed by :controller after 
  # shifting the key from PATH_INFO to SCRIPT_NAME.
  #
  #   server = Server.new
  #   server.controllers['sample'] = lambda do |env|
  #     [200, {}, ["Sample got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]]
  #   end
  #
  #   req = Rack::MockRequest.new(server)
  #   req.get('/sample/path/to/resource').body      # => "Sample got /sample : /path/to/resource"
  #
  # Server automatically maps unknown keys to controllers discovered via the
  # env.controllers manifest.  The only requirement is that the controller
  # constant is a Rack application.  For instance:
  #
  #   # [lib/example.rb] => %q{
  #   # ::controller
  #   # class Example
  #   #   def self.call(env)
  #   #     [200, {}, ["Example got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]]
  #   #   end
  #   # end 
  #   # }
  #
  #   req.get('/example/path/to/resource').body     # => "Example got /example : /path/to/resource"
  #
  # If desired, controllers can be set with aliases to map a path key to a
  # lookup key.
  #
  #   server.controllers['sample'] = 'example'
  #   req.get('/sample/path/to/resource').body      # => "Example got /sample : /path/to/resource"
  #
  # If no controller can be found, the request is routed using the
  # default_controller_key and the request is NOT adjusted.
  #
  #   server.default_controller_key = 'app'
  #   server.controllers['app'] = lambda do |env|
  #     [200, {}, ["App got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]]
  #   end
  #
  #   req.get('/unknown/path/to/resource').body     # => "App got  : /unknown/path/to/resource"
  #
  # In development mode, the controller constant is removed and the constant
  # require path is reloaded each time it gets called.  This system allows many
  # web frameworks to be hooked into a Tap server.
  #
  # :::+
  class Server
    class << self
      
      # Instantiates a Server in the specified directory, configured as
      # specified in root/server.yml.  If shutdown_key is specified, a
      # random shutdown key will be generated and set on the sever.
      #
      def instantiate(root, secret=false)
        # setup the server directory
        root = File.expand_path(root)
        FileUtils.mkdir_p(root) unless File.exists?(root)

        # initialize the server
        env = Tap::Exe.setup(root)
        env.activate
        config = Configurable::Utils.load_file(env.root['server.yml'])
        
        server = new(env, config)
        server.config[:secret] = rand(10000000000) if secret
        server
      end
    end
    
    include Rack::Utils
    include Configurable
    
    config :servers, %w[thin mongrel webrick], {        # a list of preferred handlers
      :long => :server
    }, &c.list 
    
    config :host, 'localhost', &c.string                # the server host
    config :port, 8080, &c.integer                      # the server port
    
    # Server implements a secret for HTTP administration of the server (ex
    # remote shutdown). Under many circumstances this functionality is
    # undesirable; specify a nil secret, the default, to prevent remote
    # administration.
    config :secret, nil, &c.string_or_nil               # the admin secret
    
    # 
    nest(:env, Tap::Env, :type => :hidden)
    
    # 
    nest(:app, Tap::App, :type => :hidden)
    
    # The persistence directory structure for self.
    nest(:persistence, Persistence, :type => :hidden)
    
    attr_accessor :controller
    attr_reader :handler
    attr_accessor :thread
    
    def initialize(controller=nil, config={})
      @controller = controller
      @handler = nil
      @thread = nil
      @cache = {}
      initialize_config(config)
    end
    
    def uri(path=nil, params={})
      query = build_query(params)
      "http://#{host}:#{port}#{path}#{query.empty? ? '' : '?'}#{query}"
    end
    
    def path(dir, path)
      env.path(dir, path) {|path| File.file?(path) }
    end
    
    def class_path(dir, obj, path)
      env.class_path(dir, obj, path) {|path| File.file?(path) }
    end
    
    # Returns true if input is equal to the secret, if a secret is set. Used
    # to test if a particular request has rights to a remote administrative
    # action.
    def admin?(input)
      secret != nil && input == secret
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