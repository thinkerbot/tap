require 'tap/task'
require 'readline'

module Tap
  module Tasks
    # :startdoc::prompt
    class Prompt < Task
    
      def call
        puts "starting prompt (help for help):"
        loop do
          begin
            line = Readline.readline('--/', true).strip
            next if line.empty?

            args = Shellwords.shellwords(line)
            "/#{args.shift}" =~ Tap::Parser::SIGNAL

            result = app.call('obj' => $1, 'sig' => $2, 'args' => args)
            if result == app
              break
            else
              puts "=> #{result}"
            end
          rescue
            puts $!.message
            puts $!.backtrace if app.debug?
          end
        end
      end
    end
  end
end
    