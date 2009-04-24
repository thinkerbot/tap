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

      def sh_test(cmd)
        unless cmd =~ /\A\s#{command_pattern}(.*?)\n(.+)\z/m
          raise "invalid sh_test command: #{cmd}"
        end

        start = Time.now
        result = sh(command + $1)
        finish = Time.now

        assert_equal $2, result, command + $1
        puts "  (#{time(start, finish)}s) #{command_pattern + $1}" if ENV['VERBOSE'] == 'true'
      end

      def sh_match(cmd, *regexps)
        unless cmd =~ /\A#{command_pattern}(.*?)\z/
          raise "invalid sh_match command: #{cmd}"
        end

        start = Time.now
        result = sh(command + $1)
        finish = Time.now

        regexps.each do |regexp|
          assert_match regexp, result, command_pattern + $1
        end
        puts "  (#{time(start, finish)}s) #{command_pattern + $1}" if ENV['VERBOSE'] == 'true'
      end

      def time(start, finish)
        "%.3f" % [finish-start]
      end
    end
  end
end