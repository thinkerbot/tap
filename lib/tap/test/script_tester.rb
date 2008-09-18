require 'tap/support/shell_utils'
require 'tap/test/regexp_escape'

module Tap
  module Test

    class ScriptTester
      include Tap::Support::ShellUtils
      
      # The command path for self, returned by to_s
      attr_accessor :command_path
      
      # An array of (command, message, expected, validation)
      # entries, representing the accumulated test commands.
      attr_reader :commands
      
      attr_reader :stepwise, :run_block
      
      def initialize(command_path=nil, stepwise=false, &run_block)
        @command_path = command_path
        @commands = []
        @stepwise = stepwise
        @run_block = run_block
      end
      
      # Splits the input string, collecting single-line commands
      # and expected results.  Nil will be used as the expected
      # result if the result is whitespace, or not present.
      #
      #   cmd = ScriptTest.new
      #   cmd.split %Q{
      #   % command one
      #   expected text for command one
      #   % command two
      #   % command three
      #   expected text for command three
      #   }  
      #   # => [
      #   # ["command one", "expected text for command one\n"],
      #   # ["command two", nil],
      #   # ["command three", "expected text for command three\n"]] 
      #
      def split(str)
        str.split(/^%\s*/).collect do |s| 
          next(nil) if s.strip.empty?
          command, expected = s.split(/\n/, 2)
          expected = nil if expected && expected.strip.empty?
          [command.strip, expected]
        end.compact
      end
      
      def time(msg, command)
        commands << [command, msg, nil, nil]
      end
      
      def check(msg, command, use_regexp_escapes=true, &validation)
        new_commands = split(command)
        commands = new_commands.collect do |cmd, expected|
          expected = RegexpEscape.new(expected) if expected && use_regexp_escapes
          [cmd, msg, expected, validation]
        end
        
        run(commands)
      end

      def match(msg, command, regexp=nil, &validation)
        new_commands = split(command)
        commands = new_commands.collect do |cmd, expected|
          raise "expected text specified in match command" unless expected == nil
          [cmd, msg, regexp, validation]
        end
        
        run(commands)
      end
      
      def run(commands)
        commands.each_with_index do |(cmd, msg, expected, validation), i|
          start = Time.now
          result = capture_sh(cmd) {|ok, status, tempfile_path| }
          elapsed = Time.now - start
          
          cmd_msg = commands.length > 1 ? "#{msg} (#{i})" : msg
          run_block.call(expected, result, %Q{#{cmd_msg}\n% #{cmd}}) if expected
          validation.call(result) if validation

          if stepwise
            print %Q{
------------------------------------
%s
> %s
%s
Time Elapsed: %.3fs} % [cmd_msg, cmd, result, elapsed]

            print "\nContinue? (y/n): "
            break if gets.strip =~ /^no?$/i
          else
            puts "%.3fs : %s" % [elapsed, cmd_msg]
          end
        end
      end
    
      # Returns the command path.
      def to_s
        command_path
      end

    end
  end
end