require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware default debugger
    class Debugger < Middleware
      def call(task, input)
        app.log "#{app.var(task)}", "<< #{summarize input} (#{task.class})"
        output = super
        
        app.log "#{app.var(task)}", ">> #{summarize output} (#{task.class})"
        output
      end
      
      def summarize(obj)
        obj.inspect
      end
    end
  end
end