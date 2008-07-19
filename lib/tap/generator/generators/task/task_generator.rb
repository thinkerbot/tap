module Tap::Generator::Generators
  
  # ::generator generates a Tap::Task
  #
  class TaskGenerator < Tap::Generator::Base 
    
    config :test, true, &c.switch  # Generates the task without test files.
    
    def manifest(m, *argv)
      m.template app.filepath(:lib, "#{target_dir}.rb"), "task.erb", default_attributes, :nesting => nesting
          
      if test
        m.template app.filepath(:test, "#{target_dir}_test.rb"), "test.erb"
      end
    end

  end
end