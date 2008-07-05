module Tap::Generator::Generators
  class GeneratorGenerator < Rails::Generator::NamedBase # :nodoc:
    def initialize(*args)
      super(*args)    
      @destination_root  = Tap::App.instance[:root]
      @app = Tap::App.instance
      
      raise "Sorry - generator names cannot be nested.  Try '#{file_name}' by itself." unless class_path.empty?
  	end

    def manifest
      record do |m|
        generators_root = @app.relative_filepath(:root, @app['lib/generators'])
        m.directory File.join(generators_root, file_name, "templates")
        
        m.template "generator.erb", File.join(generators_root,  file_name, file_name + "_generator.rb")
        m.template "usage.erb",  File.join(generators_root, file_name, "USAGE")
      end
    end
  end
end