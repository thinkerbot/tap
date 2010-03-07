require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(options={})
    env = Env.new
    env.ns '/tap'
    env.ns '/tap/tasks'
    
    lib = File.expand_path('..', __FILE__)
    pattern = 'tap/{join,signal,tasks/load,tasks/dump,tasks/prompt}.rb'
    Env::Constant.scan(lib, pattern).each do |constant|
      env.constants[constant.const_name] = constant
    end
    
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
    
    if auto_path = options[:auto_path]
      Env::Path.split(auto_path).each {|dir| env.auto(:dir => dir) }
    end
    
    if env_path = options[:env_path]
      env.signal(:load).call Env::Path.split(env_path)
    end
    
    if taprc_path = options[:taprc_path]
      app.signal(:load).call Env::Path.split(taprc_path)
    end
    
    app
  end
end