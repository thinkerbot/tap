require 'tap'
require 'rack'
require 'rack/mock'
require 'tap/controller'

module Tap
  Tap::Env.manifest(:controllers) do |env|
    entries = env.root.glob(:controllers, "*_controller.rb").collect do |path|
      const_name = File.basename(path).chomp('.rb').camelize
      Support::Constant.new(const_name, path)
    end
    
    Support::Manifest.intern(entries) do |manifest, const|
      const.basename.chomp('_controller')
    end
  end
  
  # ::manifest
  class Server < Tap::Task
    
    # Matches a request-method url (a url preceded with 'get@' or 'post@').
    # After the match:
    #
    #   $1:: get or post
    #   $2:: everything after the @
    #
    # Example:
    #
    #   'get@/url' =~ METHOD_URI
    #   $1     # => 'get'
    #   $2     # => '/url'
    #
    METHOD_URI = /^(get|post)@(.*)$/
    
    # Matches url to parse out a controller key and everything else.
    # After the match:
    #
    #   $1:: first segement of a url path
    #   $2:: everything following
    #
    # Example:
    #
    #   '/key/a/b/c' =~ CONTROLLER_ROUTE
    #   $1     # => 'key'
    #   $2     # => '/a/b/c'
    #
    CONTROLLER_ROUTE = /^\/(.*?)(\/.*)?$/
    
    config :dev, false, :short => 'd', &c.flag
    config :host, 'localhost'
    config :port, 8080, &c.integer
    config :default_method, 'get'
    
    nest :env, Env do |config|
      case config
      when Env then config
      else Env.new.reconfigure(config)
      end
    end
    
    config :controllers, {}, &c.hash
    
    def process(uri="/")
      method = default_method
      if uri =~ METHOD_URI
        method, uri = $1, $2
      end
      
      uri = URI(uri[0] == ?/ ? uri : "/#{uri}")
      uri.host ||= host
      uri.port ||= port
      
      mock = Rack::MockRequest.new(self)
      mock.request(method, uri.to_s)
    end
    
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      env.reset if dev
      
      # determine path_info
      path_info = rack_env["PATH_INFO"].to_s
      path_info =~ CONTROLLER_ROUTE
      key, path = $1, ($2 || '/')
      
      # route to a controller
      unless controller = lookup(key)
        path = path_info
        controller = lookup('app')
      end
      
      unless controller
        raise "could not route: #{path_info}"
      end
      
      # set environment variables
      rack_env['tap.server'] = self
      rack_env['tap.original_path_info'] = path_info
      rack_env['PATH_INFO'] = path.to_s
      
      controller.call(rack_env)
    rescue(Controller::ErrorMessage)
      [500, {'Content-Type' => 'text/plain'}, "#{$!.message}"]
    rescue(Exception)
      [500, {'Content-Type' => 'text/plain'}, "500 #{$!.class}: #{$!.message}\n#{$!.backtrace.join("\n")}"]
    end
    
    protected
    
    # Looks up a controller registered with env.  If key is already a
    # controller (ie it responds to call) then it is returned directly.
    # Returns nil if no controller can be found.
    #
    # ==== Development mode
    # In development mode, controllers are reloaded each time lookup
    # is called.
    # 
    def lookup(key) # :nodoc:
      key = controllers[key] || key
      
      case
      when key.respond_to?(:call) then key
      when const = env.controllers.search(key)
        # load the require_path in dev mode so that
        # controllers will be reloaded each time
        if dev && const.require_path
          if Object.const_defined?(const.const_name)
            Object.send(:remove_const, const.const_name)
          end
          
          load const.require_path
        end
        
        const.constantize
      else nil
      end
    end
  end
end