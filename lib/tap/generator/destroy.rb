module Tap
  module Generator
    module Destroy
      def iterate(actions)
        actions.reverse_each {|action| yield(action) }
      end
      
      def directory(path, options={})
        path = File.expand_path(path, target_dir)
        
        case
        when !File.exists?(path)
          log_relative :missing, path
        when !file_task.dir_empty?(path)
          log_relative 'not empty', path
        else
          log_relative :rm, path
          file_task.added_files << File.expand_path(path)
          file_task.rmdir(path) unless pretend    
        end
      end
    
      def file(path, options={})
        path = File.expand_path(path, target_dir)
        
        if File.exists?(path)
          log_relative :rm, path
          file_task.added_files << File.expand_path(path)
          file_task.rm(path) unless pretend
        else
          log_relative :missing, path
        end
      end
    end
    
  end
end
