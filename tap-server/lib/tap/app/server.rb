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
      
      # Returns the state of app.
      def state
        app.state.to_s
      end
      
      # Returns pong
      def ping
        "pong"
      end
      
      # Returns the controls and current application info.
      def info(secret=nil)
        render view_path('info.erb'), :locals => {
          :actions => [:run, :stop, :terminate, :reset],
          :secret => secret
        }
      end
      
      # Renders information about the execution environment.
      def about(secret=nil)
        return "" unless admin?(secret)
        render view_path('about.erb')
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
        if request.post?
          app.reset
          tasks.clear
        end
        
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
        unless request.post?
          return render(view_path('schema.erb'))
        end
        
        schema = if request[:parse] == "on"
          Tap::Schema.parse(request[:schema])
        else
          Tap::Schema.load(request[:schema])
        end
        
        @tasks = schema.build(app) do |type, metadata|
          case metadata
          when Array
            Constant.new(metadata.shift.camelize)
          when Hash
            Constant.new(metadata[:class], metadata[:require_path])
          else
            raise "invalid metadata: #{metadata.inspect}"
          end.constantize
        end
        
        if request[:run] == "on"
          run
        else
          redirect(:enque)
        end
      end
      
      def enque
        unless request.post?
          return render(view_path('enque.erb'))
        end
        
        queue = if request[:load]
          YAML.load(request[:queue] || "{}")
        else
          request[:queue] || {}
        end
        
        queue.each do |(key, inputs)|
          unless task = tasks[key]
            raise "no task for: #{key}"
          end
          
          app.enq(task, *inputs)
        end
        
        redirect :info
      end
      
      # Returns the pid if the correct secret is provided
      def pid(secret=nil)
        return "" unless admin?(secret)
        Process.pid.to_s
      end
      
      # Terminates app and stops self (on post).
      def shutdown(secret=nil)
        if admin?(secret) && request.post?        
          synchronize do
            app.terminate
            thread.join if thread
          end
          
          # wait a bit to shutdown, so the response is sent out.
          Thread.new { sleep(0.1); stop! }
          "shutdown"
        else
          ""
        end
      end
      
      # ensure server methods are not added as actions
      set :define_action, false
      set :default_action, :info
      
      attr_reader :app
      attr_reader :tasks
      attr_reader :thread
      
      config_attr :views_dir, nil do |input|     # the views directory
        @views_dir = (input || "views/#{self.class.to_s.underscore}")
      end
      
      config :secret, nil, &c.string_or_nil      # the admin secret
      
      def initialize(config={}, app=Tap::App.new)
        @app = app
        @tasks = {}
        @thread = nil
        initialize_config(config)
        super()
      end
      
      # Returns true if input is equal to the secret, or if no secret is set.
      # This method is used to test if a particular request has rights to an
      # administrative action.
      def admin?(input)
        secret == nil || input == secret
      end
      
      def call(env)
        super(env)
      rescue ServerError
        $!.response
      rescue Exception
        ServerError.response($!)
      end
      
      def view_path(path)
        File.join(views_dir, path)
      end
    end
  end
end