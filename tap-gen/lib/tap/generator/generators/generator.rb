require 'tap/generator/generators/resource'

module Tap::Generator::Generators
  
  # :startdoc::generator a generator task and test
  #
  # Generates a new generator.
  class Generator < Resource
    
    def manifest(m, const_name)
      const = super
      
      # make the templates directory
      m.directory path('templates', const.path)
      
      # make a template file
      # (note it's easier to do this as a file since erb is
      # added, and would have to be escaped in a template)
      m.file path('templates', const.path, 'template_file.erb') do |file|
        file << "# A sample template file.\nkey: <%= format key %>\n"
      end
      
      const
    end
  end
end