require 'tap/controller'
require 'rack/mime'
require 'time'

class AppController < Tap::Controller
  set :default_layout, 'layouts/default.erb'
  
  def call(env)
    # serve public files before actions
    server = env['tap.server'] ||= Tap::Server.new
    
    if path = server.public_path(env['PATH_INFO'])
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
    env_names = {}
    server.env.minimap.each do |name, environment|
      env_names[environment] = name
    end 
    
    render('index.erb', :locals => {:env => server.env, :env_names => env_names}, :layout => true)
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
      path = app.subpath(:log, 'server.log')
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
end