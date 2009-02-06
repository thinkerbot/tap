require 'tap/controller'
require 'rack/mime'
require 'time'
require 'json'
class AppController < Tap::Controller
  self.default_layout = 'layouts/default.erb'
  
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
      render('info.erb', :locals => {:update => true, :info => app.info}, :layout => true)
    end
  end
  
  def tail
    path = dereference(request['id'] || log_key)
    pos = request['pos'].to_i
    
    params = {
      :path => File.basename(path),
      :id => reference(path),
      :pos => pos,
      :update => true
    }
    
    case
    when path == nil
      params.merge!(:update => false, :content => "")
      
    when File.exists?(path) # && permission
      if pos > File.size(path)
        raise Tap::ServerError, "tail position out of range"
      end
      
      File.open(path) do |file|
        file.pos = pos
        params[:content] = file.read
        params[:pos] = file.pos
      end
    else
      raise Tap::ServerError, "non-existant file: #{path}"
    end
    
    if request.post?
      params.to_json
    else
      render('tail.erb', :locals => params, :layout => true)
    end
  end
  
  def run
    request['id'] = log_key
    app.run
    tail
  end
  
  def stop
    app.stop
    info
  end
  
  def terminate
    app.terminate
    info
  end
  
  protected
  
  def app
    Tap::App.instance
  end
  
  def reference(obj)
    key = rand(10000).to_s
    session[key] = obj
    key
  end
  
  def dereference(key)
    session[key]
  end
  
  def setup_app
    log_file = server.env.root.prepare(:log, 'server.log')
    app.logger = Logger.new(log_file)
    reference(log_file)
  end
  
  def log_key
    @log_key ||= setup_app
  end
end