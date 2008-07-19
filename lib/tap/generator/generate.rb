module Tap
  module Generator 
    module Generate
      def iterate(actions)
        actions.each {|action| yield(action) }
      end
  
      def directory(path, options={})
        path = File.expand_path(path, target_dir)
        
        if File.exists?(path)
          log_relative :exists, path
        else
          log_relative :create, path
          file_task.mkdir(path) unless pretend
        end
      end
    
      def file(path, options={})
        path = File.expand_path(path, target_dir)
        
        case
        when !File.exists?(path)
          log_relative :create, path
          # should check for identical...
        when force_file_collision?(path)
          log_relative :force, path
        else
          log_relative :skip, path
          return
        end
        
        unless pretend
          file_task.prepare(path) 
          File.open(path, "wb") {|file| yield(file) if block_given? }
        end
      end
      
      # Ask the user interactively whether to force collision.
      def force_file_collision?(destination)
        return false if skip
        return true if force
        
        $stdout.print "overwrite #{destination}? [Ynaiq] "
        $stdout.flush
        case $stdin.gets
        when /a/i
          $stdout.puts "forcing #{name}"
          force = true
        when /i/i
          $stdout.puts "ignoring #{name}"
          skip = true
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
