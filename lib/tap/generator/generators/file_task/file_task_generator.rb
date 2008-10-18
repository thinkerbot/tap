require 'tap/generator/generators/task/task_generator'

module Tap::Generator::Generators
  
  # Tap::Generator::Generators::FileTaskGenerator::generator a file_task and test
  #
  # Generates a new Tap::FileTask and associated test files.
  class FileTaskGenerator < TaskGenerator
    
    def manifest(m, const_name)
      const = super
      
      if test
        test_dir = app.filepath('test', const.path, "test_#{const.basename}")
        
        m.directories test_dir, %W{
          input
          expected
        }
        
        m.template File.join(test_dir, 'input/file.txt'), "file.txt", :const => const, :test_dir => test_dir
        m.template File.join(test_dir, 'expected/result.yml'), "result.yml", :const => const, :test_dir => test_dir
      end
    end
    
  end
end