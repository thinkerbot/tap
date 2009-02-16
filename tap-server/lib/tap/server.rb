require 'rack'
require 'rack/mock'

require 'tap'
require 'tap/server_error'

module Tap
  Env.manifest(:controllers) do |env|
    entries = env.root.glob(:controllers, "*_controller.rb").collect do |path|
      const_name = File.basename(path).chomp('.rb').camelize
      Support::Constant.new(const_name, path)
    end

    Support::Manifest.intern(entries) do |manifest, const|
      const.basename.chomp('_controller')
    end
  end
  
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
  #     [200, {}, "Sample got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]
  #   end
  #
  #   req = Rack::MockRequest.new(server)
  #   req.get('/sample/path/to/resource').body      # => "Sample got /sample : /path/to/resource"
  #
  # Server automatically maps unknown keys to a controller by searching
  # env.controllers.  As a result '/example' maps to the ExampleController
  # defined in 'controllers/example_controller.rb'.
  #
  #   # [controllers/example_controller.rb] => %q{
  #   # class ExampleController
  #   #   def self.call(env)
  #   #     [200, {}, "ExampleController got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]
  #   #   end
  #   # end 
  #   # }
  #
  #   req.get('/example/path/to/resource').body     # => "ExampleController got /example : /path/to/resource"
  #
  # If desired, controllers can be set with aliases to map a path key to a
  # lookup key.
  #
  #   server.controllers['sample'] = 'example'
  #   req.get('/sample/path/to/resource').body      # => "ExampleController got /sample : /path/to/resource"
  #
  # If no controller can be found, the request is routed using the
  # default_controller_key and the request is NOT adjusted.
  #
  #   server.default_controller_key = 'app'
  #   server.controllers['app'] = lambda do |env|
  #     [200, {}, "App got #{env['SCRIPT_NAME']} : #{env['PATH_INFO']}"]
  #   end
  #
  #   req.get('/unknown/path/to/resource').body     # => "App got  : /unknown/path/to/resource"
  #
  class Server
    include Rack::Utils
    include Configurable
    
    config :environment, :development
    config :server, %w[thin mongrel webrick]
    config :host, 'localhost'
    config :port, 8080, &c.integer
    
    config :views_dir, :views
    config :public_dir, :public
    config :controllers, {}
    config :default_controller_key, 'app'
    
    attr_reader :env
    
    def initialize(env=Env.new, app=Tap::App.instance, config={})
      @env = env
      @app = app
      @cache = {}
      initialize_config(config)
    end
    
    # Currently a stub for initializing a session.  initialize_session returns
    # an integer session id.
    def initialize_session
      id = 0
      session_app = app(id)
      log_path = session_app.prepare(:log, 'server.log')
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
          session_app.prepare(:results, id.to_s, "#{class_name}#{extname}") do |file|
            file << Support::Templater.new(File.read(template)).build(:_result => _result)
          end
        end
      end
      
      id
    end
    
    # Returns the app provided during initialization.  In the future this
    # method may be extended to provide a session-specific App, hence it
    # has been stubbed with an id input.
    def app(id=nil)
      @app
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
        rack_env['SCRIPT_NAME'] = "#{rack_env['SCRIPT_NAME'].chomp('/')}/#{key}"
        rack_env['PATH_INFO'] = "/#{path_info}"
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
        if Object.const_defined?(const.const_name)
          Object.send(:remove_const, const.const_name)
        end
      
        load const.require_path
      end
    
      @cache[key] = const.constantize
    end
  end
end