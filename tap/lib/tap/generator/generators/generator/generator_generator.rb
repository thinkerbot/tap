module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::GeneratorGenerator::generator a generator task and test
  #
  # Generates a new generator.
  class GeneratorGenerator < Tap::Generator::Base
    
    def manifest(m, const_name)
      const = Constant.new(const_name.camelize)
      dir= File.join('lib', const.path)
      
      # make the directory
      m.directory app.filepath(dir)
      
      # make the generator
      m.template app.filepath(dir, const.basename + '_generator.rb'), "task.erb", :const => const
      
      # make the templates directory
      m.directory app.filepath(dir, 'templates')
      m.file app.filepath(dir, 'templates', 'template_file.erb') do |file|
        file.puts "# A sample template file."
        file.puts "key: <%= key %>"
      end
      
    end
  end
end