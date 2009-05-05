require 'tap/generator/generators/task'

module Tap::Generator::Generators
  
  # :startdoc::generator a generator task and test
  #
  # Generates a new generator.
  class Generator < Tap::Generator::Generators::Task
    
    config :test, true, &c.switch  # specifies creation of a test file
    
    def manifest(m, const_name)
      super
      
      const = Tap::Env::Constant.new(const_name.camelize)
      
      # make the templates directory
      m.directory path('templates', const.path)
      
      # make a template file
      # (note it's easier to do this as a file since erb is
      # added, and would have to be escaped in a template)
      m.file path('templates', const.path, 'template_file.erb') do |file|
        file << "# A sample template file.\nkey: <%= key %>\n"
      end
    end
  end
end