require 'tempfile'

module Tap
  module Generator
    
    # A mixin defining how to run manifest actions.
    module Generate
      
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
          FileUtils.mkdir_p(target) unless pretend
        end
        
        target
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
        
        copy_file = true
        msg = case
        when !File.exists?(target)
          :create
        when FileUtils.cmp(source, target)
          :exists
        when force_file_collision?(target)
          :force
        else
          copy_file = false
          :skip
        end
        
        log_relative msg, target
        if copy_file && !pretend
          dir = File.dirname(target)
          FileUtils.mkdir_p(dir) unless File.exists?(dir) 
          FileUtils.mv(source, target, :force => true)
        end
        
        target
      end
      
      # Returns :generate
      def action
        :generate
      end
      
      protected
      
      # Ask the user interactively whether to force collision.
      def force_file_collision?(target)
        return false if skip
        return true if force
        
        prompt_out.print "overwrite #{target}? [Ynaiq] "
        prompt_out.flush
        case prompt_in.gets.strip
        when /^y(es)?$/i
          true
        when /^n(o)?$/i
          false
        when /^a(ll)?$/i
          self.force = true
          true
        when /^i(gnore)?$/i
          self.skip = true
          false
        when /^q(uit)?$/i
          prompt_out.puts "aborting"
          raise SystemExit
        else force_file_collision?(target)
        end
      end
    end
  end
end
