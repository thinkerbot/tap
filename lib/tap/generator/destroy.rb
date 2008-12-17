module Tap
  module Generator
    
    # A mixin defining how to run manifest actions in reverse.
    module Destroy
      
      # Iterates over the actions in reverse.
      def iterate(actions)
        actions.reverse_each {|action| yield(action) }
      end
      
      # Removes the target directory if it exists.  Missing, non-directory and 
      # non-empty targets are simply logged and not removed.  When pretend is
      # true, removal is logged but does not actually happen.
      #
      # No options currently affect the behavior of this method. 
      def directory(target, options={})
        target = File.expand_path(target)
        
        case
        when !File.exists?(target)
          log_relative :missing, target
        when !File.directory?(target)
          log_relative 'not a directory', target
        when !Root.empty?(target)
          log_relative 'not empty', target
        else
          log_relative :rm, target
          FileUtils.rmdir(target) unless pretend
        end
      end
      
      # Removes the target file if it exists.  Missing and non-file and targets
      # are simply logged and not removed.  When pretend is true, removal is 
      # logged but does not actually happen.
      #
      # No options currently affect the behavior of this method.
      def file(target, options={})
        target = File.expand_path(target)
        
        case
        when File.file?(target)
          log_relative :rm, target
          FileUtils.rm(target) unless pretend
        when File.directory?(target)
          log_relative 'not a file', target
        else
          log_relative :missing, target
        end
      end
      
    end
  end
end
