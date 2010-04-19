require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware default debugger
    #
    # Logs the execution of tasks with their inputs.  Debugger outputs the
    # same information as App.exe will output when the app is set to debug. To
    # avoid duplication, debugger ONLY logs execution when the app is not in
    # debug mode, or when force is set.
    #
    class Debugger < Middleware
      config :force, false, &c.flag    # Force logging
      
      def call(task, input)
        log("#{app.var(task)} <<", "#{summarize input} (#{task.class})")
        output = super
        
        log("#{app.var(task)} >>", "#{summarize output} (#{task.class})")
        output
      end
      
      def log(action, msg)
        if force || !app.debug
          app.log(action, msg)
        end
      end
      
      def summarize(obj)
        obj.inspect
      end
    end
  end
end