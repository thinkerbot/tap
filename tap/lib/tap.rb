require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(dir=Dir.pwd, options={})
    env = Env.new
    env.ns '/tap'
    env.ns '/tap/tasks'
    env.ns '/tap/joins'
    env.set 'Tap::Join',          'tap/join.rb'
    env.set 'Tap::Signal',        'tap/signal.rb'
    env.set 'Tap::Tasks::Load',   'tap/tasks/load.rb'
    env.set 'Tap::Tasks::Dump',   'tap/tasks/dump.rb'
    env.set 'Tap::Tasks::Prompt', 'tap/tasks/prompt.rb'
    env.set 'Tap::Joins::Sync',   'tap/joins/sync.rb'
    env.set 'Tap::Joins::Gate',   'tap/joins/gate.rb'
    
    env_dirs = options[:env_dirs] || ENV['TAP_ENV_DIRS'] || ['.']
    Env::Path.split(env_dirs).each {|dir| env.auto(:dir => dir) }
    
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    load = app.signal(:load)
    
    rc_path = options[:taprc_path] || ENV['TAPRC'] || ['~/.taprc']
    load.call Env::Path.split(rc_path)
    
    App.instance = app
  end
end