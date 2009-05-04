require 'tap'                # excessive
require 'tap/controller'
require 'tap/server/base'
require 'thread'

module Tap
  class App
    class Server < Tap::Controller
      include Tap::Server::Base
      include MonitorMixin
      
      Constant = Tap::Env::Constant
      
      # The basic form controls for running an app.
      CONTROLS = [:run, :stop, :terminate, :reset].collect do |action|
%Q{<form action="#{action}" style="display:inline" method="post">
<input type="submit" value="#{action}" />
</form>}
      end.join("")
      
      SCHEMA = %Q{
<form action="schema" method="post">
<textarea rows="10" cols="40" name="schema"></textarea><br/>
<input type="checkbox" name="parse">parse</input>
<input type="checkbox" name="run">run</input>
<input type="submit" value="build" />
</form>}
      
      # Returns the state of app.
      def state
        app.state.to_s
      end
      
      # Returns the controls and current application info.
      def info
        "#{CONTROLS}<br/>#{app.info}"
      end
      
      # Runs app on a separate thread (on post).
      def run
        synchronize do
          @thread ||= Thread.new do 
            app.run
            @thread = nil
          end
        end if request.post?
        
        redirect :info
      end
      
      def reset
        app.reset if request.post?
        redirect :info
      end
      
      # Stops app (on post).
      def stop
        app.stop if request.post?
        redirect :info
      end
      
      # Teminates app (on post).
      def terminate
        app.terminate if request.post?
        redirect :info
      end
      
      def schema
        return SCHEMA unless request.post?
        
        schema = if request[:parse] == "on"
          Tap::Schema.parse(request[:schema])
        else
          Tap::Schema.load(request[:schema])
        end
        
        nodes = schema.build(app) do |type, metadata|
          const = case metadata
          when Array
            Constant.new(metadata.shift.camelize)
          when Hash
            Constant.new(metadata[:class], metadata[:require_path])
          else raise "invalid metadata: #{metadata.inspect}"
          end
          
          const.constantize
        end
        
        if request[:run] == "on"
          run
        else
          redirect(:info)
        end
      end
      
      # Terminates app and stops self (on post).
      def shutdown
        if request.post?
          synchronize do
            app.terminate
            thread.join if thread
          end
        
          stop!
        end
        
        ""
      end
      
      # ensure server methods are not added as actions
      set :define_action, false
      set :default_action, :info
      
      attr_reader :app
      attr_reader :nodes
      attr_reader :thread
      
      def initialize(config={}, app=Tap::App.new)
        @app = app
        @nodes = {}
        @thread = nil
        initialize_config(config)
        super()
      end
      
      def call(env)
        super(env)
      rescue ServerError
        $!.response
      rescue Exception
        ServerError.response($!)
      end
    end
  end
end