require 'tap/controller'
require 'json'

class AppController < Tap::Controller
  def index
    env.render(:views, 'index.erb')
  end
  
  def info
    params = {:update => true, :info => app.info}
    req.post? ? params.to_json : env.render(:views, 'info.erb', params)
  end
  
  def tail
    path = req.params['path'] || log_file
    pos = req.params['pos'].to_i
    
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
        raise ErrorMessage, "tail position out of range"
      end
      
      File.open(path) do |file|
        file.pos = pos
        params[:content] = file.read.chomp
        params[:pos] =  file.pos
      end
    else
      raise ErrorMessage, "non-existant file: #{path}"
    end
    
    req.post? ? params.to_json : env.render(:views, 'tail.erb', params)
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
    log_file = env.root.prepare(:log, 'server.log')
    app.logger = Logger.new(log_file)
    log_file
  end
  
  def log_file
    @log_File ||= setup_app
  end
end