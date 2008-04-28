module Tap::Generator::Generators
  class ConfigGenerator < Rails::Generator::NamedBase # :nodoc:
    attr_accessor :formatted_yaml

    def initialize(argv, options)
      @app = Tap::App.instance
      name, @version = @app.deversion(argv[0])
      argv[0] = name
      
      super(argv, options)    
      
      @destination_root  = Tap::App.instance[:root]
  	end

    def manifest
      record do |m|
        task = @app.task(class_name)
        self.formatted_yaml = task.class.configurations.format_yaml
    
        config_path = @app.relative_filepath(:root, @app[:config])
        
        if @version == nil
          # then get the next increment?
          # Tap::App.vglob(File.join(config_path, class_name.underscore + '.yml'))
        end
        version = @version == nil ? '' : "-#{@version}"
        
        m.directory File.join(config_path, class_path)
        m.template "config.erb", File.join(config_path, class_name.underscore + "#{version}.yml")
        
      end
    end
    
  end
end