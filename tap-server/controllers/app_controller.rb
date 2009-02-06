require 'tap/controller'
require 'tap/models/tail'

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
  
  def tail(id=log_id)
    tail = dereference(id)
    
    unless tail
      raise Tap::ServerError, "no path for id: #{id.inspect}"
    end
    
    if request.post?
      tail.content
    else
      render('tail.erb', :locals => {
        :id => id,
        :path => File.basename(tail.path),
        :update => true,
        :content => tail.content
      }, :layout => true)
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
  
  def session
    request.env['rack.session'] ||= {}
  end
  
  def reference(obj)
    key = rand(10000)
    session[key] = obj
    key
  end
  
  def dereference(key)
    session[key.to_i]
  end
  
  def setup_app
    log_file = server.env.root.prepare(:log, 'server.log')
    app.logger = Logger.new(log_file)
    log_file
  end
  
  def log_file
    @log_file ||= setup_app
  end
  
  def log_id
    reference(Tap::Models::Tail.new(log_file))
  end
end