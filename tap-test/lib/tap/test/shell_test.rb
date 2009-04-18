module Tap
  module Test
    module ShellTest
      def shell_path(path)
        if RUBY_PLATFORM =~ /mswin/
          File.expand_path(path).gsub("/", "\\")
        else
          "'#{File.expand_path(path)}'"
        end
      end
      
      def sh(cmd)
        IO.popen(cmd) do |io|
          yield(io) if block_given?
          io.read
        end
      end
    end
  end
end