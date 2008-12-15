module Tap
  module Generator 
    module Generate
      def iterate(actions)
        actions.each {|action| yield(action) }
      end
  
      def directory(target, options={})
        target = File.expand_path(target)
        
        if File.exists?(target)
          log_relative :exists, target
        else
          log_relative :create, target
          file_task.mkdir(target) unless pretend
        end
      end
    
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
        
        $stdout.print "overwrite #{target}? [Ynaiq] "
        $stdout.flush
        case $stdin.gets
        when /a/i
          self.force = true
        when /i/i
          self.skip = true
        when /q/i
          $stdout.puts "aborting #{name}"
          raise SystemExit
        when /n/i then false
        when /y/i then true
        else force_file_collision?(destination)
        end
      end
    end
  end
end
