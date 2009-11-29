require 'tap/app/api'
require 'readline'

module Tap
  
  # :startdoc::prompt
  #
  # A prompt to signal a running app. Any signals that return app (ie /run
  # /stop /terminate) will exit the prompt.
  class Prompt < App::Api
    
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
    