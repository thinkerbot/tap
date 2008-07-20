module Tap
  module Generator
    module Destroy
      def iterate(actions)
        actions.reverse_each {|action| yield(action) }
      end
      
      def directory(target, options={})
        target = File.expand_path(target, target_dir)
        
        case
        when !File.exists?(target)
          log_relative :missing, target
        when !file_task.dir_empty?(target)
          log_relative 'not empty', target
        else
          log_relative :rm, target
          file_task.added_files << File.expand_path(target)
          file_task.rmdir(target) unless pretend    
        end
      end
    
      def file(target, options={})
        target = File.expand_path(target, target_dir)
        
        if File.exists?(target)
          log_relative :rm, target
          file_task.added_files << File.expand_path(target)
          file_task.rm(target) unless pretend
        else
          log_relative :missing, target
        end
      end
    end
    
  end
end
