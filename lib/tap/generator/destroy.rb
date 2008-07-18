module Tap
  module Generator
    module Destroy
      def iterate(actions)
        actions.reverse_each {|action| yield(action) }
      end
      
      def directory(path)
        log_relative :rm, path
        added_files << path
        rmdir(path)
      end
    
      def file(path)
        log_relative :rm, path
        added_files << path
        rm(path)
      end
    end
    
  end
end
