require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def options
    {
      :tapfile_path => ENV['TAPFILE'],
      :gems         => ENV['TAP_GEMS'],
      :path         => ENV['TAP_PATH'],
      :tapenv_path  => ENV['TAPENV'],
      :taprc_path   => ENV['TAPRC'],
      :tap_cache    => ENV['TAP_CACHE'] || '~/.tap',
      :debug        => ENV['TAP_DEBUG']
    }
  end
  
  def setup(options=self.options)
    env = Env.new
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    App.instance = app
    
    if tapfile_path = options[:tapfile_path]
      Env::Path.split(tapfile_path).each do |tapfile|
        load(tapfile) if File.file?(tapfile)
      end
    end
    
    if gems = options[:gems]
      env.signal(:load).call Env::Gems.env_path(gems)
    end
    
    if path = options[:path]
      Env::Path.split(path).each {|dir| env.auto(:dir => dir) }
    end
    
    if tapenv_path = options[:tapenv_path]
      env.signal(:load).call Env::Path.split(tapenv_path)
    end
    
    if taprc_path = options[:taprc_path]
      app.signal(:load).call Env::Path.split(taprc_path)
    end
    
    app
  end
end