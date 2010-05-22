require 'tap/tasks/stream'
require 'readline'

module Tap
  module Tasks
    # :startdoc::task open a prompt
    #
    # Prompt reads signals from the input until a signal that returns the app
    # is reached (ex run/stop) or the source io is closed.
    #
    #   % tap prompt
    #   /set 0 load
    #   /set 1 dump
    #   /build join 0 1
    #   /enq 0 'goodnight moon'
    #   /run
    #   goodnight moon
    #
    # Prompts can be registered to a control signal (ex INT) so that that a
    # running app may be interrupted, interrogated, or modified. This infinite
    # loop can be stopped using ctl-C and a prompt.
    #
    #  % tap dump '.' - join 0 0 -q - prompt --on INT
    #  .
    #  .
    #  .
    #  (ctl-C)
    #  /stop
    #
    class Prompt < Stream
      include Tap::Utils
      
      config :prompt, '/', &c.string_or_nil         # The prompt sequence
      config :terminal, $stdout, &c.io_or_nil       # The terminal IO
      config :variable, '', &c.string_or_nil        # Assign to variable in app
      config :on, nil, &c.string_or_nil             # Register to a SIG
      
      def initialize(*args)
        super
        trap(on) if on
      end
      
      # Traps interrupt the normal flow of the program and so I assume thread
      # safety is an issue (ex if the INT occurs during an enque and a signal
      # specifies another enque). A safer way to go is to enque the prompt...
      # when the prompt is executed the app won't be be doing anything else so
      # thread safety shouldn't be an issue.
      def trap(sig)
        ::Signal.trap(sig) do
          puts
          puts "Interrupt! Signals from an interruption are not thread-safe."
          
          call_prompt = true
          3.times do
            print "Wait for thread-safe break? (y/n): "

            case gets.strip
            when /^y(es)?$/i
              puts "waiting for break..."
              app.enq(self, [])
              call_prompt = false
              break

            when /^no?$/i
              break
            end
          end

          if call_prompt
            call([])
          end
        end
      end
      
      def signal(sig)
        lambda do |spec|
          app.build('class' => sig, 'spec' => spec) do |obj, args|
            obj.call(args)
          end
        end
      end
      
      def process(io=$stdin)
        app.set(variable, self) if variable
        
        result = super(io)
        unless file || result.nil? || result == app
          open_io(terminal) do |terminal|
            terminal.puts result
          end
        end
        
        app.set(variable, nil) if variable
        result
      end
      
      def load(io)
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
        if io == $stdin && terminal == $stdout
          return Readline.readline(prompt, true)
        end
        
        if prompt && !file
          open_io(terminal) do |terminal|
            terminal.print prompt
          end
        end
        
        io.eof? ? '' : io.readline.strip!
      end
      
      def complete?(io, result)
        result == app
      end
    end
  end
end