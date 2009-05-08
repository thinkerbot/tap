require 'tap'
require 'tap/server/base'
require 'tap/server/session'
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
      
      # Runs the server
      def run(server)
        cookie_server = Rack::Session::Pool.new(server)
        server.run!
      end
    end
    
    include Utils
    include Base
    include Rack::Utils
    
    config :mode, :development, &c.select(:development, :production, &c.symbol)
    config :use_multiple_sessions, false
    
    # A hash of (key, controller) pairs mapping the controller part of a route
    # to a Rack application.  Typically controllers is used to specify aliases
    # when the defaults are not preferable.
    config :controllers, {}
    
    # config :infer_controllers, true, &c.switch
    
    # The default controller key used in routes that cannot be directly mapped
    # to a controller
    #--
    # Set to nil to force controller mapping?
    config :default_controller_key, 'server'
    
    attr_reader :env
    
    def initialize(env=Env.new, config={})
      @env = env
      @cache = {}
      @handler = nil
      initialize_config(config)
    end
    
    def initialize_session
      id = 0
      while File.exists?(session_path(id))
        id = random_key(id)
      end if use_multiple_sessions
      
      session(id)
      id
    end
    
    def session_path(id)
      if use_multiple_sessions
        env.root.path(:session, id.to_s)
      else
        env.root.root
      end
    end
    
    # Returns or initializes a session for the specified id.
    def session(id)
      path = session_path(id)
      config_path = path ? File.join(path, Session::CONFIG_FILE) : nil
      
      if config_path && File.exists?(config_path)
        Session.new YAML.load_file(config_path)
      else
        persistence = env.root.config.to_hash
        persistence[:root] = path
        Session.new(:persistence => persistence).save
      end
    end
    
    # a helper method for routing a key to a controller
    def controller(key)
      return @cache[key] if @cache.has_key?(key)
      minikey = controllers[key] || key
      
      # return registered controllers
      if minikey.respond_to?(:call)
        @cache[key] = minikey
        return minikey
      end
      
      # return if no controller can be found
      unless const = env.constant_manifest(:controller).seek(minikey)
        @cache[key] = nil
        return nil
      end
      
      # unload the controller in development mode so that
      # controllers will be reloaded each request
      const.unload if development?
      @cache[key] = const.constantize
    end
    
    def path(dir, path)
      env.path(dir, path) {|path| File.file?(path) }
    end
    
    def class_path(dir, obj, path)
      env.class_path(dir, obj, path) {|path| File.file?(path) }
    end
    
    # Returns a uri mapping to the specified controller and action.  Parameters
    # may be specified; they are built as a query and attached to the uri as
    # normal.
    #
    # Currenlty uri does not map the controller to a minipath, but in the
    # future it will.
    def uri(controller=nil, action=nil, params={})
      query = build_query(params)
      uri = ["http://#{host}:#{port}", escape(controller), action.to_s].delete_if {|s| s.empty? }.join("/")
      query.empty? ? uri : "#{uri}?#{query}"
    end
    
    def env_uri(env, controller, action=nil, params={})
      uri("#{env}:#{controller}", action, params)
    end
    
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      if development?
        env.reset
        @cache.clear
      end
      
      # route to a controller
      blank, key, path_info = rack_env['PATH_INFO'].split("/", 3)
      controller = self.controller(unescape(key))
      
      if controller
        # adjust env if key routes to a controller
        rack_env['SCRIPT_NAME'] = ["#{rack_env['SCRIPT_NAME'].chomp('/')}/#{key}"]
        rack_env['PATH_INFO'] = ["/#{path_info}"]
      else
        # use default controller key
        controller = self.controller(default_controller_key)
        
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
    
    protected
    
    # Returns true if mode is :development.
    def development? # :nodoc:
      mode == :development
    end
  end
end