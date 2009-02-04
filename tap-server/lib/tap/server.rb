require 'tap/controller'
require 'rack/mock'

module Tap
  
  # ::manifest
  class Server < Tap::Task
  
    config :environment, (ENV['RACK_ENV'] || :development).to_sym
    config :server, %w[thin mongrel webrick]
    config :host, 'localhost'
    config :port, 8080, &c.integer
    
    config :views_dir, :views
    config :public_dir, :public
  
    nest :env, Env do |config|
      case config
      when Env then config
      else Env.new.reconfigure(config)
      end
    end
    
    config :controllers, {}
    
    # analagous to Sinatra::Base.run
    # def run
    # end
    
    def process(method='get', uri="/")
      uri = URI(uri[0] == ?/ ? uri : "/#{uri}")
      uri.host ||= host
      uri.port ||= port
    
      mock = Rack::MockRequest.new(self)
      mock.request(method, uri.to_s)
    end
    
    alias redirect process
  
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      env.reset if development?
      
      # route to a controller
      blank, key, path_info = rack_env['PATH_INFO'].split("/", 3)
      controller_class = lookup(unescape(key))
      
      if controller_class
        rack_env['SCRIPT_NAME'] = "#{rack_env['SCRIPT_NAME'].chomp('/')}/#{key}"
        rack_env['PATH_INFO'] = path_info
      else
        controller_class = lookup('app')
        
        unless controller_class
          raise ServerError.new("Error 404: could not route to controller", 404)
        end
      end
      
      # handle the request
      controller_class.new(self).call(rack_env)
    rescue ServerError
      $!.response
    rescue Exception
      ServerError.response($!)
    end
    
    def development?
      environment == :development
    end
    
    def public_path(path)
      return nil unless path
      env.search(public_dir, path) {|public_path| File.file?(public_path) }
    end
    
    def template_path(path)
      return nil unless path
      env.search(views_dir, path) {|template_path| File.file?(template_path) }
    end
    
    protected
    
    def lookup(key) # :nodoc:
      # cacheable:
      #
      # return cache[key] if cache.has_key?(key)
      # return nil unless const = cache[key] =...
      #    
      return nil unless const = controllers[key] || env.controllers.search(key)
      
      # load the require_path in dev mode so that
      # controllers will be reloaded each time
      if development? && const.require_path
        if Object.const_defined?(const.const_name)
          Object.send(:remove_const, const.const_name)
        end
      
        load const.require_path
      end
    
      const.constantize
    end
  end
end