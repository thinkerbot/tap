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
      Tap.debug { [:tapfile, tapfile_path] }
      Env::Path.split(tapfile_path).each do |tapfile|
        load(tapfile) if File.file?(tapfile)
      end
    end
    
    if gems = options[:gems]
      Tap.debug { [:gems, gems] }
      
      cache_dir = options[:tap_cache]
      cache_dir = Dir.tmpdir if cache_dir.to_s.strip.empty?
      env.signal(:load).call Env::Cache.new(cache_dir).select(gems)
    end
    
    if path = options[:path]
      Tap.debug { [:path, path] }
      Env::Path.split(path).each {|dir| env.auto(:dir => dir) }
    end
    
    if tapenv_path = options[:tapenv_path]
      Tap.debug { [:tapenv, tapenv_path] }
      env.signal(:load).call Env::Path.split(tapenv_path)
    end
    
    if taprc_path = options[:taprc_path]
      Tap.debug { [:taprc, taprc_path] }
      app.signal(:load).call Env::Path.split(taprc_path)
    end
    
    app
  end
  
  def debug
    $stderr.puts("%12s: %s" % yield) if $DEBUG
  end
end