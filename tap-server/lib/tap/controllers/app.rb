require 'tap/controller'
require 'rack/mime'
require 'time'

module Tap
  module Controllers
    
    # ::controller
    class App < Tap::Controller
      include Session
      
      set :default_layout, 'layout.erb'
  
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
  
      def index
        render('index.erb', :locals => {
          :env => server.env
        }, :layout => true)
      end
      
      def info
        if request.post?
          app.info
        else
          render('info.erb', :locals => {:update => true, :content => app.info}, :layout => true)
        end
      end
  
      def tail(id)
        unless persistence.has?("#{id}.log")
          raise Tap::ServerError.new("invalid id: #{id}", 404)
        end
        
        path = persistence.path("#{id}.log")
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
  
      def run(id=nil)
        unless request.post?
          return redirect(server.uri(:schema, id))
        end
        
        if persistence.has?(id)
          schema = Tap::Support::Schema.load_file(persistence.path(id))
          server.env.build(schema, app)
        end
        
        persistence.update("#{id}.log") {|io| "waiting for results" }
        
        app.on_complete(true) do |_result|
          persistence.update("#{id}.log") do |io|
            file = class_path("result.erb", _result.key)
            locals = {:_result => _result, :value => _result.value}
            io << render(:file => file, :locals => locals)
          end
        end

        Thread.new { app.run }
        redirect uri("tail/#{id}")
      end
  
      def stop
        app.stop
        redirect uri("info")
      end
  
      def terminate
        app.terminate
        redirect uri("info")
      end
  
      def help(key=nil)
      end
    end
  end
end