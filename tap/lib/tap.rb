require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(dir=Dir.pwd, options={})
    env = Env.new
    load = env.signal(:load)
    
    env_path = options[:env_path] || ENV['TAP_ENV_PATH'] || ["tapenv"]
    Env::Path.split(env_path).each {|path| load.call [path] }
    
    gems = options[:gems] || ENV['TAP_GEMS'] || []
    Env::Path.split(gems).each {|gem_name| load.call [Gems.env_path(gem_name)] }
    
    #
    app = App.new({}, :env => env)
    load = app.signal(:load)
    
    rc_path = options[:taprc_path] || ENV['TAPRC'] || ["~/.taprc"]
    Env::Path.split(rc_path).each {|path| load.call [path] }
    
    App.instance = app
  end
end