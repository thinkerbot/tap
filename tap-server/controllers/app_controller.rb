require 'tap/controller'
require 'tap/models/tail'

require 'rack/mime'
require 'time'

class AppController < Tap::Controller
  Tail = Tap::Models::Tail
  
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
  
  def tail(id=nil)
    id = app.storage.store(Tail.new(log_file)) if id == nil
    tail = app.storage[id.to_i]
    
    unless tail.kind_of?(Tail)
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
  
  def setup_app
    log_file = server.env.root.prepare(:log, 'server.log')
    app.logger = Logger.new(log_file)
    log_file
  end
  
  def log_file
    @log_file ||= setup_app
  end
end