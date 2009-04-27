require 'tap/env'

module Tap::Generator::Generators
  
  # :startdoc::generator a generator task and test
  #
  # Generates a new generator.
  class Generator < Tap::Generator::Base
    
    config :test, true, &c.switch  # specifies creation of a test file
    
    def manifest(m, const_name)
      const = Tap::Env::Constant.new(const_name.camelize)
      dir = path('lib', const.path)
      
      # make the directory
      m.directory dir
      
      # make the generator
      m.template path(dir, "#{const.basename}_generator.rb"), "task.erb", :const => const
      
      # make the templates directory
      m.directory path('templates', const.path)
      
      # make a template file
      # (note it's easier to do this as a file since erb is
      # added, and would have to be escaped in a template)
      m.file path('templates', const.path, 'template_file.erb') do |file|
        file << "# A sample template file.\nkey: <%= key %>\n"
      end
      
      if test
        test_path = path('test', "#{const.path}_generator_test.rb")
        m.directory File.dirname(test_path)
        m.template test_path, "test.erb", :const => const
      end
    end
  end
end