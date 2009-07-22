require 'tap/tasks/stream'

module Tap
  module Tasks
    # :startdoc::task an input prompt
    #
    # Prompt reads lines from the input until the exit sequence is reached
    # or the source io is closed.  This is effectively an echo:
    #
    #   % tap run -- prompt --: dump
    #   >
    #
    class Prompt < Stream
      config :prompt, "> ", &c.string_or_nil    # The prompt sequence
      config :exit_seq, "\n", &c.string_or_nil  # The prompt exit sequence
      config :terminal, $stdout, &c.io_or_nil   # The terminal IO
      
      configurations[:use_close].default = true
      
      def load(io)
        open_io(terminal) do |terminal|
          terminal.print prompt
        end if prompt
        
        if io.eof?
          nil
        else
          io.readline
        end
      end
  
      def complete?(io, line)
        line == nil || line == exit_seq
      end
      
      def close(io)
        super
        app.terminate
      end
    end
  end
end