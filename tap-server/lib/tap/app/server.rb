require 'tap'                # excessive
require 'tap/controller'
require 'tap/server/base'

module Tap
  class App
    class Server < Tap::Controller
      include Tap::Server::Base
      
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
            
      def state
        app.state.to_s
      end
      
      def info
        "#{CONTROLS}<br/>#{app.info}"
      end
      
      def run
        if request.post?
          Thread.new { app.run }
        end
        redirect :info
      end
      
      def reset
        app.reset if request.post?
        redirect :info
      end
      
      def stop
        app.stop if request.post?
        redirect :info
      end
      
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
      
      # ensure server methods are not added as actions
      set :define_action, false
      set :default_action, :info
      
      attr_reader :app
      attr_reader :nodes
      
      def initialize(config={}, app=Tap::App.new)
        @app = app
        @nodes = {}
        
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