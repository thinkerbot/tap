require 'tap/tasks/stream'

module Tap
  module Tasks
    # :startdoc::task an input prompt
    #
    # Prompt reads signals from the input until a signal that returns the
    # app is reached (ex run/stop) or the source io is closed.
    #
    #   % tap run -- prompt
    #   /set 0 load
    #   /set 1 dump
    #   /build join 0 1
    #   /enq 0 'goodnight moon'
    #   /run
    #   goodnight moon
    #
    class Prompt < Stream
      include Tap::Utils
      
      config :prompt, "/", &c.string_or_nil         # The prompt sequence
      config :terminal, $stdout, &c.io_or_nil       # The terminal IO
      
      def signal(sig)
        lambda do |spec|
          app.build('class' => sig, 'spec' => spec) do |obj, args|
            obj.call(args)
          end
        end
      end
      
      def process(io=$stdin)
        current = app.get('')
        app.set('', self)
        
        result = super(io)
        unless file || result.nil? || result == app
          open_io(terminal) do |terminal|
            terminal.puts result
          end
        end
        
        app.set('', current)
        result
      end
      
      def load(io)
        open_io(terminal) do |terminal|
          terminal.print prompt
        end if prompt && !file
        
        return nil if io.eof?
        line = readline(io)
        return nil if line.empty?
        
        begin
          sig, *args = shellsplit(line)
          app.call('sig' => sig, 'args' => args)
        rescue
          $!
        end
      end
      
      def readline(io)
        io.readline.strip!
      end
      
      def complete?(io, result)
        result == app
      end
    end
  end
end