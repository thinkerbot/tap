require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware default debugger
    class Debugger < Middleware
      
      config :show_class, false, :long => :class, &c.flag
      config :output, $stderr, &c.io
      
      def call(task, input)
        log "+ #{identify task} #{summarize input}"
        output = super
        
        log "- #{identify task } #{summarize output}"
        output
      end
      
      def log(str)
        open_io(output) {|io| io.puts str }
      end
      
      def identify(task)
        var = app.var(task)
        show_class ? "#{var} (#{task.class})" : var.to_s
      end
      
      def summarize(obj)
        obj.inspect
      end
    end
  end
end