module Tap::Generator::Generators
  
  # :startdoc::generator a config file for a task
  # 
  # Generates a new config file for a task.  The configurations, defaults, 
  # and documentation is determined from the task source file.
  class ConfigGenerator < Tap::Generator::Base
    
    config :doc, true, &c.switch  # include documentation in the config
    
    def env
      Tap::Env.instance
    end

    def manifest(m, name, config_name=name)
      const = env.search(:tasks, name) or raise "unknown task: #{name}"
      task_class = const.constantize or raise "unknown task: #{name}"
      
      m.directory app['config']
      m.file app.filepath('config', config_name + '.yml') do |file|
        task_class.configurations.format_str((doc ? :doc : :nodoc), file)
      end
    end
    
  end
end