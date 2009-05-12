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
      
      def index
        render('index.erb', :locals => {
          :env => server.env
        }, :layout => true)
      end
      
      # Returns pong
      def ping
        response['Content-Type'] = "text/plain"
        "pong"
      end
      
      # Essentially a login for server administration
      def access
        if request.get?
          render 'access.erb', :locals => {:secret => request['secret']}, :layout => true
        else
          redirect uri("admin", :secret => request['secret'])
        end
      end
      
      # Administrate this server
      def admin(secret=nil)
        template = server.admin?(secret) ? 'admin.erb' : 'access.erb'
        render template, :locals => {:secret => secret}, :layout => true
      end
      
      # Returns the public server configurations as xml.
      def config(secret=nil)
        response['Content-Type'] = 'text/xml'
        if server.admin?(secret)
%Q{<?xml version="1.0"?>
<server>
<uri>#{uri}</uri>
<secret>#{server.secret}</secret>
</server>
}
        else
%q{<?xml version="1.0"?>
<server />
}
        end
      end
      
      # Returns the pid if the correct secret is provided
      def pid(secret=nil)
        response['Content-Type'] = "text/plain"
        
        return "" unless server.admin?(secret)
        Process.pid.to_s
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
      
      # ensure server methods are not added as actions
      set :define_action, false
      
      def call(env)
        # serve public files before actions
        server = env['tap.server'] ||= Tap::Server.new
    
        if path = server.path(:public, env['PATH_INFO'])
          content = File.read(path)
          headers = {
            "Last-Modified" => File.mtime(path).httpdate,
            "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
            "Content-Length" => content.size.to_s
          }
      
          [200, headers, [content]]
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
      def help(type, env, key)
        server.uri("help/#{type}/#{key}")
      end
      
      # Stops the server.
      def stop!
        server.stop!
      end
    end
  end
end