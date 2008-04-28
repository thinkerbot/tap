module Tap::Generator::Generators
  class CommandGenerator < Rails::Generator::NamedBase # :nodoc:
    def initialize(*args)
      super(*args)    
      @destination_root  = Tap::App.instance[:root]
      @app = Tap::App.instance
  	end

    def manifest
      record do |m|
        command_path = @app.relative_filepath(:root, @app[:cmd])
        m.directory class_path.empty? ? command_path : File.join(command_path, class_path)
        m.template "command.erb", File.join(command_path, class_name.underscore + ".rb")
      end
    end
  end
end