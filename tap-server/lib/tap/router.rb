require 'tap/server'

module Tap
  class Router < Server
    
    config :development, false, &c.flag
  
    # A hash of (key, controller) pairs mapping the controller part of a route
    # to a Rack application.  Typically controllers is used to specify aliases
    # when the defaults are not preferable.
    config :controllers, {}

    def controller_uri(env, controller, action=nil, params={})
      uri "#{escape("#{env}:#{controller}")}#{action ? '/' : ''}#{action}", params
    end

    # a helper method for routing a key to a controller
    def route(key)
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
      const.unload if development
      @cache[key] = const.constantize
    end

    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.
    def call(rack_env)
      if development
        env.reset
        @cache.clear
      end

      # route to a controller
      blank, path, path_info = rack_env['PATH_INFO'].split("/", 3)
      controller = route(unescape(path))

      if controller
        # adjust env if key routes to a controller
        rack_env['SCRIPT_NAME'] = ["#{rack_env['SCRIPT_NAME'].chomp('/')}/#{path}"]
        rack_env['PATH_INFO'] = ["/#{path_info}"]
      else
        # use main controller
        controller = self.controller
        path = nil
        
        unless controller
          raise ServerError.new("404 Error: could not route to controller", 404)
        end
      end

      # handle the request
      rack_env['tap.server'] = self
      rack_env['tap.path'] = path
      controller.call(rack_env)
    rescue ServerError
      $!.response
    rescue Exception
      ServerError.response($!)
    end
  end
end