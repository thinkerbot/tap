module Tap
  module Test
    module ShellTest
      def setup
        super
        puts method_name if ENV['VERBOSE'] == 'true'
      end
      
      def command_pattern
        self.class.const_get(:CMD_PATTERN)
      end
      
      def command
        self.class.const_get(:CMD)
      end
      
      def path(path)
        if RUBY_PLATFORM =~ /mswin/
          File.expand_path(path).gsub("/", "\\")
        else
          "'#{File.expand_path(path)}'"
        end
      end

      def tempfile
        Tempfile.open(method_name) do |io|
          yield(io, path(io.path))
        end
      end

      def sh(cmd)
        IO.popen(cmd) do |io|
          yield(io) if block_given?
          io.read
        end
      end
      
      def sh_time(cmd, &block)
        start = Time.now
        result = sh(cmd, &block)
        finish = Time.now
        
        elapsed = "%.3f" % [finish-start]
        puts "  (#{elapsed}s) #{cmd}" if ENV['VERBOSE'] == 'true'
                
        result
      end

      def sh_test(cmd)
        cmd, expected = cmd.lstrip.split(/\r?\n/, 2)
        unless cmd =~ /\A#{command_pattern}(.*)\z/
          raise "invalid sh_test command: #{cmd}"
        end
        
        result = sh_time(command + $1)
        assert_equal(expected, result, command + $1) if expected
        yield(result) if block_given?
        result
      end
    end
  end
end