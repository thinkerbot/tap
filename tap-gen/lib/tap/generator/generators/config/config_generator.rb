module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::ConfigGenerator::generator a config file for a task
  # 
  # Generates a new config file for a task.  The configurations, defaults, 
  # and documentation is determined from the task source file.
  class ConfigGenerator < Tap::Generator::Base
    
    config :doc, true, &c.switch  # include documentation in the config
    
    def env
      Tap::Env.instance
    end

    def manifest(m, name, config_name=name)
      const = env.tasks.search(name) or raise "unknown task: #{name}"
      task_class = const.constantize or raise "unknown task: #{name}"
      
      m.directory app['config']
      dump(m, app.filepath('config', config_name), task_class.configurations)
    end
    
    def template
      path = File.expand_path(doc ? 'doc.erb' : 'nodoc.erb', template_dir)
      File.read(path)
    end
    
    def dump(m, path, configurations, &block)
      non_nested_configurations = configurations.to_a.sort_by do |(key, config)|
        config.attributes[:declaration_order] || 0
      end.collect do |(key, config)|
        default = config.default(false)
        
        if default.kind_of?(Configurable::DelegateHash)
          # nest nested configs
          dump(m, File.join(path, key), default, &block)
          nil
        else
          # duplicate config so that any changes to it
          # during templation will not propogate back
          # into configurations
          [key, config.dup]
        end
      end.compact
      
      if block_given?
        yield(non_nested_configurations)
      end
      
      m.file "#{path}.yml" do |file|
        templater = Tap::Support::Templater.new(template)
        templater.configurations = non_nested_configurations
        file << templater.build
      end
    end
  end
end