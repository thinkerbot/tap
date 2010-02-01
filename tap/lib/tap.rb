require 'tap/version'
require 'tap/app'
require 'tap/env'
require 'tap/join'

module Tap
  module_function
  
  def setup(dir=Dir.pwd, options={})
    env = Env.new
    env.set Tap::Join
    env.ns 'tap'
    load = env.signal(:load)
    
    env_path = options[:env_path] || ENV['TAP_ENV_PATH'] || ["tapenv"]
    load.call Env::Path.split(env_path)
    
    gems = options[:gems] || ENV['TAP_GEMS'] || []
    Env::Path.split(gems, nil).each do |gem_name|
      load.call Env::Gems.env_files(gem_name) 
    end
    
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    load = app.signal(:load)
    
    rc_path = options[:taprc_path] || ENV['TAPRC'] || ["~/.taprc"]
    load.call Env::Path.split(rc_path)
    
    App.instance = app
  end
end