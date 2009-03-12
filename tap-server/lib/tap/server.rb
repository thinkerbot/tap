require 'rack'
require 'rack/mock'

require 'tap'
require 'tap/server_error'

module Tap
  Env.manifest(:controllers) do |env|
    controllers = Support::ConstantManifest.new('controller')
    env.load_paths.each do |path_root|
      controllers.register(path_root, '**/*.rb')
    end
    controllers
  end
  
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
  # Server automatically maps unknown keys to a controller by searching
  # env.controllers.  As a result '/example' maps to the Example controller
  # defined in 'lib/example.rb'.
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
  # :::+
  class Server
    class << self
      
      # Instantiates a Server in the specified directory, configured as
      # specified in root/server.yml.  If shutdown_key is specified, a
      # random shutdown key will be generated and set on the sever.
      #
      def instantiate(root, shutdown_key=false)
        # setup the server directory
        root = File.expand_path(root)
        FileUtils.mkdir_p(root) unless File.exists?(root)

        # initialize the server
        app = Tap::App.instance
        env = Tap::Exe.instantiate(root)
        env.activate
        config = Configurable::Utils.load_file(env.root['server.yml'])
        
        server = new(env, app, config)
        server.config[:shutdown_key] = rand(1000000) if shutdown_key
        server
      end
      
      # Runs the server
      def run(server)
        cookie_server = Rack::Session::Pool.new(server)
        server.run!
      end
    end
    
    include Rack::Utils
    include Configurable
    
    config :environment, :development                   
    config :servers, %w[thin mongrel webrick], &c.list  # a list of preferred handlers
    config :host, 'localhost', &c.string                # the server host
    config :port, 8080, &c.integer                      # the server port
    
    # The views directory used to lookup controller views.
    #--
    # bad idea... should be environment-specific
    config :views_dir, :views
    
    # The public directory.  Files under public are served directly.
    #--
    # not critically true... needs to be implemnted in server, not app
    config :public_dir, :public
    
    # A hash of (key, controller) pairs mapping the controller part of a route
    # to a Rack application.  Typically controllers is used to specify aliases
    # when the defaults are not preferable.
    config :controllers, {}
    
    # config :infer_controllers, true, &c.switch
    
    # The default controller key used in routes that cannot be directly mapped
    # to a controller
    #--
    # Set to nil to force controller mapping?
    config :default_controller_key, 'app'
    
    # Server implements a shutdown key so the server can be shutdown remotely
    # via an HTTP request to the app/shutdown method.  Remote shutdown is
    # useful when the user is running a local server (especially from a
    # background process).  Under many circumstances remote shutdown is
    # undesirable; specify a nil shutdown key, the default, to turn off
    # shutdown.
    config :shutdown_key, nil, &c.integer_or_nil        # specifies a public shutdown key
    
    attr_reader :env
    attr_reader :handler
    
    def initialize(env=Env.new, app=Tap::App.instance, config={})
      @env = env
      @app = app
      @cache = {}
      @handler = nil
      initialize_config(config)
    end
    
    # Runs self as configured, on the specified server, host, and port.  Use an
    # INT signal to interrupt.
    def run!(handler=rack_handler)
      app.log :run, "#{host}:#{port} (#{handler})"
      handler.run self, :Host => host, :Port => port do |handler_instance|
        @handler = handler_instance
        trap(:INT) { stop! }
      end
    end
    
    # Stops the server if running (ie a handler is set).  Returns true if the
    # server was stopped, and false otherwise.
    def stop!
      if handler
        # Use thins' hard #stop! if available, otherwise just #stop
        handler.respond_to?(:stop!) ? handler.stop! : handler.stop
        @handler = nil
        false
      else
        true
      end
    end
    
    # Currently a stub for initializing a session.  initialize_session returns
    # an integer session id.
    def initialize_session
      id = 0
      session_app = app(id)
      log_path = env.root.prepare(:log, 'server.log')
      session_app.logger = Logger.new(log_path)
      
      session_app.on_complete do |_result|
        # find the template
        class_name = _result.key.class.to_s.underscore
        pattern = "#{class_name}/result\.*"
        template = nil
        env.each do |e|
          templates = e.root.glob(views_dir, pattern)
          unless templates.empty?
            template = templates[0]
            break
          end
        end
        
        if template
          extname = File.extname(template)
          env.root.prepare(:results, id.to_s, "#{class_name}#{extname}") do |file|
            file << Support::Templater.new(File.read(template)).build(:_result => _result)
          end
        end
      end
      
      id
    end
    
    def uri(controller=nil, action=nil)
      ["http://#{host}:#{port}", escape(controller), action].compact.join("/")
    end
    
    # Returns the app provided during initialization.  In the future this
    # method may be extended to provide a session-specific App, hence it
    # has been stubbed with an id input.
    def app(id=nil)
      @app
    end
    
    # Returns the env.root provided during initialization.  In the future this
    # method may be extended to provide a session-specific Root, hence it
    # has been stubbed with an id input.
    def root(id=nil)
      @env.root
    end
    
    # Returns true if environment is :development.
    def development?
      environment == :development
    end
    
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      if development?
        env.reset 
        @cache.clear
      end
      
      # route to a controller
      blank, key, path_info = rack_env['PATH_INFO'].split("/", 3)
      controller = lookup(unescape(key))
      
      if controller
        # adjust env if key routes to a controller
        rack_env['SCRIPT_NAME'] = ["#{rack_env['SCRIPT_NAME'].chomp('/')}/#{key}"]
        rack_env['PATH_INFO'] = ["/#{path_info}"]
      else
        # use default controller key
        controller = lookup(default_controller_key)
        
        unless controller
          raise ServerError.new("404 Error: could not route to controller", 404)
        end
      end
      
      # handle the request
      rack_env['tap.server'] = self
      controller.call(rack_env)
    rescue ServerError
      $!.response
    rescue Exception
      ServerError.response($!)
    end
    
    #--
    # TODO: implement caching for path content
    def content(path)
      File.read(path)
    end
    
    #--
    # TODO: implement caching for public_paths
    def public_path(path)
      env.search(public_dir, path) {|public_path| File.file?(public_path) }
    end
    
    #--
    # TODO: implement caching for template_paths
    def template_path(path)
      env.search(views_dir, path) {|template_path| File.file?(template_path) }
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
    
    # a helper method for routing a key to a controller
    def lookup(key) # :nodoc:
      return @cache[key] if @cache.has_key?(key)
      minikey = controllers[key] || key
      
      # return registered controllers
      if minikey.respond_to?(:call)
        @cache[key] = minikey
        return minikey
      end
      
      # return if no controller can be found
      unless const = env.controllers.search(minikey)
        @cache[key] = nil
        return nil
      end
      
      # load the require_path in dev mode so that
      # controllers will be reloaded each time
      if development? && const.require_path
        parent = Tap::Support::Constant.constantize(const.nesting) { nil }
        if parent && parent.const_defined?(const.const_name)
          parent.send(:remove_const, const.const_name)
        end
        
        load const.require_path
      end
    
      @cache[key] = const.constantize
    end
  end
end