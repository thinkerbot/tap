require 'tap'
require 'tap/server/data'
require 'tap/server/runner'
require 'tap/server/server_error'

module Tap
  # ::configurable
  class Server
    include Runner
    
    # Server implements a secret for HTTP administration of the server (ex
    # remote shutdown). Under many circumstances this functionality is
    # undesirable; specify a nil secret, the default, to prevent remote
    # administration.
    config :secret, nil, &c.string_or_nil           # the admin secret
    
    config :development, false, &c.flag
    
    config :router, true, &c.switch
    
    nest :env, Tap::Env, :type => :hidden
    
    nest :app, Tap::App, :type => :hidden
    
    nest :data, Data, :type => :hidden
    
    attr_accessor :controller
    attr_accessor :thread
    
    def initialize(controller=nil, config={})
      @controller = controller
      @thread = nil
      super(config)
    end
    
    # Returns true if input is equal to the secret, if a secret is set. Used
    # to test if a particular request has rights to a remote administrative
    # action.
    def admin?(input)
      secret != nil && input == secret
    end
    
    def route(rack_env)
      return controller unless router
      
      # route to a controller
      blank, route, path_info = rack_env['PATH_INFO'].split("/", 3)
      controller = lookup_controller(unescape(route))
      
      if controller
        # adjust rack_env if route routes to a controller
        rack_env['SCRIPT_NAME'] = ["#{rack_env['SCRIPT_NAME'].chomp('/')}/#{route}"]
        rack_env['PATH_INFO'] = ["/#{path_info}"]
      else
        # use default controller
        controller = self.controller
        route = nil
      end
      
      rack_env['tap.route'] = route
      controller
    end

    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      # handle the request
      rack_env['tap.server'] = self
      
      unless controller = route(rack_env)
        raise ServerError.new("404 Error: could not route to controller", 404)
      end
      
      controller.call(rack_env)
    rescue ServerError
      $!.response
    rescue Exception
      ServerError.response($!)
    end
    
    def run!
      super(self)
    end
    
    protected
    
    def lookup_controller(key) # :nodoc:
      if development
        # unload the controller in development mode so that
        # controllers will be reloaded each request
          
        env.reset
        if const = env[:controller].seek(key)
          const.unload
          const.constantize
        else
          nil
        end
      else
        env[:controller][key]
      end
    end
  end
end