module Tap::Generator::Generators
  
  # ::generator generates a Tap::Task
  #
  class TaskGenerator < Tap::Generator::Base 
    
    config :test, true, &c.switch  # Generates the task without test files.
    
    def manifest(m, const_name)
      const = Constant.new(const_name.camelize)
      
      task_path = app.filepath(:lib, "#{const.path}.rb")
      m.directory File.dirname(task_path)
      m.template task_path, "task.erb", :const => const
          
      if test
        test_path = app.filepath(:test, "#{const.path}_test.rb")
        m.directory File.dirname(test_path)
        m.template test_path, "test.erb", :const => const
      end
    end

  end
end