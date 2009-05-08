require 'tap'
require 'tap/controller'
require 'thread'
require 'monitor'

module Tap
  class App
    class Api < Tap::Controller
      include MonitorMixin
      Constant = Tap::Env::Constant
      
      # The directory containing the default views for an Api controller.
      DEFAULT_API_VIEWS_DIR = File.expand_path(File.dirname(__FILE__) + "/../../../views/tap/app/api")
      
      # Returns the state of app.
      def state
        app.state.to_s
      end
      
      # Returns pong
      def ping
        response['Content-Type'] = "text/plain"
        "pong"
      end
      
      # Returns the controls and current application info.
      def info
        render 'info.erb', :locals => {
          :actions => [:run, :stop, :terminate, :reset],
        }, :layout => true
      end
      
      # Runs app on a separate thread (on post).
      def run
        synchronize do
          @thread ||= Thread.new do 
            app.run
            @thread = nil
          end
        end if request.post?
        
        redirect uri(:info)
      end
      
      def reset
        app.reset if request.post?
        redirect uri(:info)
      end
      
      # Stops app (on post).
      def stop
        app.stop if request.post?
        redirect uri(:info)
      end
      
      # Teminates app (on post).
      def terminate
        app.terminate if request.post?
        redirect uri(:info)
      end
      
      def build
        unless request.post?
          return render('build.erb', :layout => true)
        end
        
        schema = if request[:parse] == "on"
          Tap::Schema.parse(request[:schema])
        else
          Tap::Schema.load(request[:schema])
        end

        app.cache[:tasks] = schema.build(app) do |type, metadata|
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
          redirect uri(:enque)
        end
      end
      
      def enque
        unless request.post?
          return render('enque.erb', :layout => true)
        end
        
        queue = if request[:load]
          YAML.load(request[:queue] || "{}")
        else
          request[:queue] || {}
        end
        
        tasks = app.cache[:tasks] ||= {}
        queue.each do |(key, inputs)|
          unless task = tasks[key]
            raise "no task for: #{key}"
          end
          app.enq(task, *inputs)
        end
        
        redirect uri(:info)
      end
      
      # ensure server methods are not added as actions
      set :define_action, false
      set :default_action, :info
      
      attr_reader :app
      attr_reader :thread
      
      def initialize(app=Tap::App.new)
        @app = app
        @thread = nil
        super()
      end
      
      # Used to generate a uri to an Api action. Must be implemented in
      # subclasses.
      def uri(action=nil, params={})
        raise NotImplementedError
      end
      
      # Used to test if a particular request has rights to a remote
      # administrative action.  Must be implemented in subclasses.
      def admin?(input)
        raise NotImplementedError
      end
      
      # Used to shutdown the server.  Must be implemented in subclasses.
      def stop!
        raise NotImplementedError
      end
    end
  end
end