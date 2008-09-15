require 'tap/support/shell_utils'
require 'tap/test/script_methods/regexp_escape'

module Tap
  module Test
    module ScriptMethods
      class ScriptTest
        include Tap::Support::ShellUtils
        
        # The command path for self, returned by to_s
        attr_accessor :command_path
        
        # An array of (command, message, expected, validation)
        # entries, representing the accumulated test commands.
        attr_reader :commands

        def initialize(command_path=nil)
          @command_path = command_path
          @commands = []
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
          new_commands.each_with_index do |(cmd, expected), i|
            expected = RegexpEscape.new(expected) if expected && use_regexp_escapes
            commands << [cmd, (new_commands.length > 1 ? "#{msg} (#{i})" : msg), expected, validation]
          end
        end

        def match(msg, command, regexp=nil, &validation)
          new_commands = split(command) 
          new_commands.each_with_index do |(cmd, expected), i|
            raise "expected text specified in match command" unless expected == nil
            commands << [cmd, (new_commands.length > 1 ? "#{msg} (#{i})" : msg), regexp, validation]
          end
        end
        
        def run(stepwise=false)
          commands.each do |cmd, msg, expected, validation|
            start = Time.now
            result = capture_sh(cmd) {|ok, status, tempfile_path| }
            elapsed = Time.now - start

            yield(expected, result, %Q{#{msg}\n% #{cmd}}) if expected
            validation.call(result) if validation

            if stepwise
              print %Q{
------------------------------------
%s
> %s
%s
Time Elapsed: %.3fs} % [msg, cmd, result, elapsed]

              print "\nContinue? (y/n): "
              break if gets.strip =~ /^no?$/i
            else            
              puts "%.3fs : %s" % [elapsed, msg]
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
end