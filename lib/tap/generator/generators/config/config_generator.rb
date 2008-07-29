module Tap::Generator::Generators
  
  # ::generator
  # 
  # Generates a new config file for a Task.  The configurations, defaults, 
  # and documentation is determined from the task.rb file.  Pass the task 
  # name, either CamelCased or under_scored.
  # 
  # Versioned config files can be generated as well.  Specify a version by 
  # appending the version to the task name.
  # 
  #   # generates the config file 'config/sample_task'  
  #   # for SampleTask from 'lib/sample_task.rb'
  #   % tap generate config sample_task
  # 
  # ::generator-   
  #   # now with a version, the output config 
  #   # file is 'config/sample_task-0.1.yml'
  #   % tap generate config sample_task-0.1
  #       
  class ConfigGenerator < Tap::Generator::Base
    
    config :doc, true, &c.switch  # Generates the config w/wo documentation.
    
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