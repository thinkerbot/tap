module Tap
  module Generator
    module Destroy
      def iterate(actions)
        actions.reverse_each {|action| yield(action) }
      end
      
      def directory(path)
        if File.exists?(path)
          log_relative :rm, path
          added_files << File.expand_path(path)
          rmdir(path)
        else
          log_relative :missing, path
        end
      end
    
      def file(path)
        if File.exists?(path)
          log_relative :rm, path
          added_files << File.expand_path(path)
          rm(path)
        else
          log_relative :missing, path
        end
      end
    end
    
  end
end
