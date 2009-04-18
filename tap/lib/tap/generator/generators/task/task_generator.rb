require 'tap/env'

module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::TaskGenerator::generator a task and test
  #
  # Generates a new Tap::Task and an associated test file.
  class TaskGenerator < Tap::Generator::Base
    
    config :test, true, &c.switch  # specifies creation of a test file
    
    def manifest(m, const_name)
      const = Tap::Env::Constant.new(const_name.camelize)
      
      task_path = path('lib', "#{const.path}.rb")
      m.directory File.dirname(task_path)
      m.template task_path, "task.erb", :const => const
      
      if test
        test_path = path('test', "#{const.path}_test.rb")
        m.directory File.dirname(test_path)
        m.template test_path, "test.erb", :const => const
      end
    end

  end
end