require 'tap/task'

module Tap
  module Tasks
    # ::manifest send signals to a process
    #
    class Signal < Tap::Task
      class << self
        def parse!(argv=ARGV, app=Tap::App.instance)
          super do |opts|
            opts.on("-l", "--list", "list available signals") do
              signals.each {|(sig, n)| puts "  #{sig}: #{n}" }
              exit
            end
          end
        end
        
        def signal?(obj)
          ::Signal.list.any? {|(signal, int)| obj == signal || obj == int }
        end
        
        def signals
          ::Signal.list.to_a.sort_by {|(sig, n)| n }
        end
      end
      
      config :signal, "INT" do |signal|               # the signal to send (ex INT, KILL)
        signal =~ /\A\d+\z/ ? signal.to_i : signal.upcase
        
        unless signal?(signal)
          raise "unknown or unsupported signal: #{signal}"
        end
        
        signal
      end
      
      config :preview, false, :short => :p, &c.flag   # log but don't send signal
      config :file, false, :short => :f, &c.flag      # read pid from file
      config :cleanup, true, &c.switch                # cleanup pid file (if file)
      
      def process(pid)
        pid_file = pid
        pid = File.read(pid_file) if file
        
        log :signal, "#{signal} #{pid}#{preview ? ' (preview)' : ''}"
        
        unless preview
          Process.kill(signal, pid.to_i)
          
          if file && cleanup
            FileUtils.rm(pid_file)
          end
        end
      end
      
    end 
  end
end