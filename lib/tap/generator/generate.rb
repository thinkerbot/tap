module Tap
  module Generator
    
    # A mixin defining how to run manifest actions.
    module Generate
      
      # Iterates over the actions in order.
      def iterate(actions)
        actions.each {|action| yield(action) }
      end
      
      # Creates the target directory if it doesn't exist.  When pretend is
      # true, creation is logged but does not actually happen.
      #
      # No options currently affect the behavior of this method.
      def directory(target, options={})
        target = File.expand_path(target)
        
        case
        when File.exists?(target)
          log_relative :exists, target
        else
          log_relative :create, target
          file_task.mkdir_p(target) unless pretend
        end
      end
      
      # Creates the target file; content may be added to the file by providing
      # block.  If the target file already exists, the new and existing content
      # is compared and the user will be prompted for how to handle collisions.
      # All activity is logged.  When pretend is true, creation is logged but
      # does not actually happen.
      #
      # No options currently affect the behavior of this method.
      def file(target, options={})
        source_file = Tempfile.new('generate')
        yield(source_file) if block_given?
        source_file.close
        
        source = source_file.path
        target = File.expand_path(target)
        
        copy_file = case
        when !File.exists?(target)
          log_relative :create, target
          true
        when FileUtils.cmp(source, target)
          log_relative :exists, target
          false
        when force_file_collision?(target)
          log_relative :force, target
          true
        else
          log_relative :skip, target
          false
        end
        
        if copy_file && !pretend
          file_task.prepare(target) 
          FileUtils.mv(source, target)
        end
      end
      
      protected
      
      # Ask the user interactively whether to force collision.
      def force_file_collision?(target)
        return false if skip
        return true if force
        
        prompt_out.print "overwrite #{target}? [Ynaiq] "
        prompt_out.flush
        case prompt_in.gets
        when /a/i
          self.force = true
        when /i/i
          self.skip = true
        when /q/i
          prompt_out.puts "aborting #{name}"
          raise SystemExit
        when /n/i then false
        when /y/i then true
        else force_file_collision?(destination)
        end
      end
    end
  end
end
