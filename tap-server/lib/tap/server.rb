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
  
  class Server
    include Rack::Utils
    include Configurable
    
    config :environment, (ENV['RACK_ENV'] || :development).to_sym
    config :server, %w[thin mongrel webrick]
    config :host, 'localhost'
    config :port, 8080, &c.integer
    
    config :views_dir, :views
    config :public_dir, :public
    config :controllers, {}
    
    attr_accessor :env
    
    def initialize(env=Env.new, config={})
      @env = env
      @cache = {}
      initialize_config(config)
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
        # default to AppController, if possible
        controller = lookup('app')
        
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
    
    # a helper method for routing a key to a controller
    def lookup(key) # :nodoc:
      return @cache[key] if @cache.has_key?(key)
      
      minikey = controllers[key] || key
      if minikey.respond_to?(:call)
        @cache[key] = minikey
        return minikey
      end
      
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