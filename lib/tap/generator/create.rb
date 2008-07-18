module Tap
  module Generator 
    module Generate
      def iterate(actions)
        actions.each {|action| yield(action) }
      end
  
      def directory(path)
        if File.exists?(path)
          log_relative :exists, path
        else
          log_relative :create, path
          mkdir(path)
        end
      end
    
      def file(path)   
        case
        when !File.exists?(path)
          log_relative :create, path
        when force_file_collision?(path)
          log_relative :force, path
        else
          log_relative :skip, path
          return
        end
          
        prepare(path)
        File.open(path, "wb") {|file| yield(file) if block_given? }
      end
      
      # Ask the user interactively whether to force collision.
      def force_file_collision?(destination, src)
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
        else force_file_collision?(destination, src)
        end
      end
    end
  end
end
