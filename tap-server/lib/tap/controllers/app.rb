require 'tap/controller'
require 'rack/mime'
require 'json/pure'
require 'time'

module Tap
  module Controllers
    
    # ::controller
    class App < Tap::Controller
      set :default_layout, 'layout.erb'
  
      def call(env)
        # serve public files before actions
        server = env['tap.server'] ||= Tap::Server.new
    
        if path = server.public_path(env['PATH_INFO'])
          content = File.read(path)
          headers = {
            "Last-Modified" => [File.mtime(path).httpdate],
            "Content-Type" => [Rack::Mime.mime_type(File.extname(path), 'text/plain')], 
            "Content-Length" => [content.size.to_s]
          }
      
          [200, headers, [content]]
        else
          super
        end
      end
  
      def index
        env_names = {}
        server.env.minimap.each do |name, environment|
          env_names[environment] = name
        end 
    
        render('index.erb', :locals => {:env => server.env, :env_names => env_names}, :layout => true)
      end
      
      # Returns 'ping'.
      def ping
        response['Content-Type'] = 'text/plain'
        "ping"
      end
      
      # Returns a JSON hash of public server configurations.
      def config
        response['Content-Type'] = 'application/json'
        { :uri => uri,
          :shutdown_key => shutdown_key
        }.to_json
      end
      
      # Shuts down the server.  Shutdown requires a shutdown key which
      # is setup when the server is launched.  If no shutdown key was
      # setup, shutdown does nothing and responds accordingly.
      def shutdown
        if shutdown_key && request['shutdown_key'].to_i == shutdown_key
          # wait a second to shutdown, so the response is sent out.
          Thread.new {sleep 1; Tap::Server.kill }
          "shutdown"
        else
          "you do not have permission to shutdown this server"
        end
      end
      
      def info
        if request.post?
          app.info
        else
          render('info.erb', :locals => {:update => true, :content => app.info}, :layout => true)
        end
      end
  
      #--
      # Currently tail is hard-coded to tail the server log only.
      def tail(id=nil)
        begin
          path = root.subpath(:log, 'server.log')
          raise unless File.exists?(path)
        rescue
          raise Tap::ServerError.new("invalid path", 404)
        end
    
        pos = request['pos'].to_i
        if pos > File.size(path)
          raise Tap::ServerError.new("tail position out of range (try update)", 500)
        end

        content = File.open(path) do |file|
          file.pos = pos
          file.read
        end
    
        if request.post?
          content
        else
          render('tail.erb', :locals => {
            :id => id,
            :path => File.basename(path),
            :update => true,
            :content => content
          }, :layout => true)
        end
      end
  
      def run
        Thread.new { app.run }
        redirect("/app/tail")
      end
  
      def stop
        app.stop
        redirect("/app/info")
      end
  
      def terminate
        app.terminate
        redirect("/app/info")
      end
  
      def help(key=nil)
      end
      
      protected
      
      # returns the server shutdown key.  the shutdown key is required
      # for shutdown to function, a nil shutdown key disables shutdown.
      def shutdown_key  # :nodoc:
        server.config[:shutdown_key]
      end
    end
  end
end