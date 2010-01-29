require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  
  def setup(dir=Dir.pwd, options)
    env = Env.new
    envload = env.signal(:load)
    
    env_path = options[:env_path] || ENV['TAP_ENV_PATH'] || ["tapenv"]
    split(env_path).each {|path| envload.call path }
    
    gems = options[:gems] || ENV['TAP_GEMS'] || []
    split(gems).each {|gem_name| envload.call Gems.env_path(gem_name) }
    
    #
    app = App.new({}, :env => env)
    appload = app.signal(:load)
    
    rc_path = options[:taprc_path] || ENV['TAPRC'] || ["~/.taprc"]
    split(rc_path).each {|path| appload.call path }
    
    App.instance = app
  end
end