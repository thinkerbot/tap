require 'tap/controller'
require 'rack/mime'
require 'time'

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
    params = {:update => true, :info => app.info}
    if request.post? 
    else
      render('info.erb', :locals => params, :layout => true)
    end
  end
  
  def tail
    path = request.params['path'] || log_file
    pos = request.params['pos'].to_i
    
    params = {
      :path => path,
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
        params[:content] = file.read.chomp
        params[:pos] =  file.pos
      end
    else
      raise Tap::ServerError, "non-existant file: #{path}"
    end
    
    if request.post? 
    else
      render('tail.erb', :locals => params, :layout => true)
    end
  end
  
  def run
    req.params[:path] = log_file
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
  
  def setup_app
    log_file = server.env.root.prepare(:log, 'server.log')
    app.logger = Logger.new(log_file)
    log_file
  end
  
  def log_file
    @log_File ||= setup_app
  end
end