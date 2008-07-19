module Tap::Generator::Generators
  
  # ::generator generates a Tap::Task
  #
  class TaskGenerator < Tap::Generator::Base 
    
    
    #     def initialize(*args)
    #       super(*args)    
    #       @destination_root  = Tap::App.instance[:root]
    #       @app = Tap::App.instance
    # end
    # 
    #     def manifest
    #       record do |m|
    #         lib_path = @app.relative_filepath(:root, @app[:lib])
    #         m.directory File.join(lib_path, class_path)
    #         m.template "task.erb", File.join(lib_path, class_name.underscore + ".rb"), :class_nesting => class_nesting
    #         
    #         if options[:test]
    #           test_path = @app.relative_filepath(:root, @app[:test])
    #           m.directory File.join(test_path, class_path)
    #           m.template "test.erb", File.join(test_path, class_name.underscore + "_test.rb")
    #         end
    #         
    #         task_manifest(m)
    #       end
    #     end
    #     
    #     def task_manifest(m)
    #     end
    #     
    #     def add_options!(opt)
    #       options[:test] = true
    #       opt.on(nil, '--[no-]test', 'Generates the task without test files.') { |value| options[:test] = value }
    #     end

  end
end