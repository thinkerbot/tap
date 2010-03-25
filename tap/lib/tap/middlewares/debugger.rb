require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware the default debugger
    class Debugger < Middleware
      
      config :show_class, false, :long => :class, &c.flag
      config :output, $stderr, &c.io
      
      def call(node, input)
        log "+ #{identify node} #{summarize input}"
        output = super
        
        log "- #{identify node } #{summarize output}"
        output
      end
      
      def log(str)
        open_io(output) {|io| io.puts str }
      end
      
      def identify(node)
        var = app.var(node)
        show_class ? "#{var} (#{node.class})" : var.to_s
      end
      
      def summarize(obj)
        obj.inspect
      end
    end
  end
end