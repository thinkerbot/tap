require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(dir=Dir.pwd, options={})
    env = Env.new
    env.ns '/tap'
    env.set 'Tap::Join', "tap/join.rb"
    env.set 'Tap::Signal', "tap/signal.rb"
    
    env_dirs = options[:env_dirs] || ENV['TAP_ENV_DIRS'] || ['.']
    Env::Path.split(env_dirs).each {|dir| env.auto(:dir => dir) }
    
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    load = app.signal(:load)
    
    rc_path = options[:taprc_path] || ENV['TAPRC'] || ["~/.taprc"]
    load.call Env::Path.split(rc_path)
    
    App.instance = app
  end
end