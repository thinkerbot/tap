require 'tap/generator/generators/task/task_generator'

module Tap::Generator::Generators
  class FileTaskGenerator < TaskGenerator # :nodoc:
    
    def task_manifest(m)
      return unless options[:test]
      
      test_path = @app.relative_filepath(:root, @app[:test])
      m.directory File.join(test_path, class_name.underscore)
        
      method_test_path = File.join(test_path, class_name.underscore, "test_#{file_name.underscore}")
      m.directory method_test_path
      m.directory File.join(method_test_path, "input")
      m.directory File.join(method_test_path, "expected")
        
      m.file "file.txt", File.join(method_test_path, "input", "file.txt")
      m.file "file.yml", File.join(method_test_path, "expected", "file.yml")
    end
    
  end
end