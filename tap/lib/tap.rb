require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(options={})
    env = Env.new
    env.ns '/tap'
    env.ns '/tap/tasks'
    env.set 'Tap::Join',          'tap/join.rb'
    env.set 'Tap::Signal',        'tap/signal.rb'
    env.set 'Tap::Tasks::Load',   'tap/tasks/load.rb'
    env.set 'Tap::Tasks::Dump',   'tap/tasks/dump.rb'
    env.set 'Tap::Tasks::Prompt', 'tap/tasks/prompt.rb'
    
    if auto_path = options[:auto_path]
      Env::Path.split(auto_path).each {|dir| env.auto(:dir => dir) }
    end
    
    if env_path = options[:env_path]
      env.signal(:load).call Env::Path.split(env_path)
    end
    
    app = App.new({}, :env => env)
    app.set('app', app)
    app.set('env', env)
    
    if taprc_path = options[:taprc_path]
      app.signal(:load).call Env::Path.split(taprc_path)
    end
    
    App.instance = app
  end
end