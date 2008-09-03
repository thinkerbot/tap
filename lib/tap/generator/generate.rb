module Tap
  module Generator 
    module Generate
      def iterate(actions)
        actions.each {|action| yield(action) }
      end
  
      def directory(target, options={})
        target = File.expand_path(target, target_dir)
        
        if File.exists?(target)
          log_relative :exists, target
        else
          log_relative :create, target
          file_task.mkdir(target) unless pretend
        end
      end
    
      def file(target, options={})
        prepare(target, options) do |path|
          File.open(path, "wb") {|file| yield(file) if block_given? }
        end
      end
      
      def prepare(target, options={})
        target = File.expand_path(target, target_dir)
        
        case
        when !File.exists?(target)
          log_relative :create, target
          # should check for identical...
        when force_file_collision?(target)
          log_relative :force, target
        else
          log_relative :skip, target
          return
        end
        
        unless pretend
          file_task.prepare(target) 
          yield(target)
        end
      end
      
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
