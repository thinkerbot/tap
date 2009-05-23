require 'tap/controller'
require 'rack/mime'
require 'time'

module Tap
  module Controllers
    
    # :startdoc::controller remotely controls and monitor a server
    # 
    # Server provides several uris to control and monitor the server behavior.
    # Importantly, server allows the remote shutdown of a Tap::Server if a
    # shutdown_key is set.  This makes it possible to run servers in the
    # background and still have a shutdown handle on them.
    #
    class Server < Tap::Controller
      include Utils
      
      def index
        render('index.erb', :layout => true)
      end
      
      # Returns pong
      def ping
        response['Content-Type'] = "text/plain"
        "pong"
      end
      
      # Essentially a login for server administration
      def access
        if request.get?
          render 'access.erb', :locals => {
            :secret => request['secret']
          }, :layout => true
        else
          redirect uri("admin", :secret => request['secret'])
        end
      end
      
      # Administrate this server
      def admin(secret=nil)
        template = server.admin?(secret) ? 'admin.erb' : 'access.erb'
        render template, :locals => {:secret => secret}, :layout => true
      end
      
      # Terminates app and stops self (on post).
      def shutdown(secret=nil)
        response['Content-Type'] = "text/plain"
        
        if server.admin?(secret) && request.post?
          # wait a bit to shutdown, so the response is sent out.
          Thread.new { sleep(0.1); server.stop! }
          "shutdown"
        else
          ""
        end
      end
      
      def help(type=nil, *key)
        if const = server.env[type][key.join('/')]
          module_render 'help.erb', const
        else
          "unknown #{type}: #{key.join('/')}"
        end
      end
      
      # ensure server methods are not added as actions
      set :define_action, false
      
      def call(rack_env)
        path = rack_env['tap.server'].env.path(:public, rack_env['PATH_INFO']) {|file| File.file?(file) }
        if path
          static_file(path)
        else
          super
        end
      end
      
      # Returns a controller uri, attaching the secret to the action, if specified.
      def uri(action=nil, params={})
        secret = params.delete(:secret)
        
        if secret
          action = action ? "#{action}/#{secret}" : secret
        end
        
        super(action, params)
      end
      
      # Returns a help uri for the specified resource, currently only sketched out.
      def help_uri(type, key)
        uri("help/#{type}/#{key}")
      end
      
      # Stops the server.
      def stop!
        server.stop!
      end
      
    end
  end
end