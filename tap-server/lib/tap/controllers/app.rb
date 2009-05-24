require 'tap/controller'
require 'tap/controllers/schema'

module Tap
  module Controllers
    
    # :startdoc::controller builds and runs workflows
    class App < Tap::Controller
      set :default_action, :info
      
      nest :schema, Schema do
        def dispatch(route)
          route.unshift rest_action(route)
          super(route)
        end
      end
      
      # Returns the state of app.
      def state
        app.state.to_s
      end
      
      # Returns the controls and current application info.
      def info
        render 'info.erb', :locals => {
          :actions => [:run, :stop, :terminate, :reset],
        }, :layout => true
      end
      
      # Runs app on a separate thread (on post).
      def run
        if request.post?
          server.thread ||= Thread.new { app.run; server.thread = nil; }
        end
        
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
        schema = request[:schema] || server.data.read(:schema, request[:id])
        
        unless request.post?
          return render('build.erb', :schema => schema, :layout => true)
        end
        
        schema = Tap::Schema.load(schema).resolve! do |type, key, data|
          server.env.manifest(type)[key]
        end.validate!
        
        if request[:reset] == "on"
          app.reset
        end
        
        tasks.merge!(server.env.build(schema, app))
        
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
        
        queue.each do |(key, inputs)|
          unless task = tasks[key]
            raise "no task for: #{key}"
          end
          app.enq(task, *inputs)
        end
        
        redirect uri(:info)
      end
      
      def tail(id)
        unless data.has?("#{id}.log")
          raise Tap::ServerError.new("invalid id: #{id}", 404)
        end
        
        path = data.path("#{id}.log")
        pos = request['pos'].to_i
        if pos > File.size(path)
          raise Tap::ServerError.new("tail position out of range (try update)", 500)
        end

        content = File.open(path) do |file|
          file.pos = pos
          file.read
        end
    
        if request.post?
          content
        else
          render('tail.erb', :locals => {
            :id => id,
            :path => File.basename(path),
            :update => true,
            :content => content
          }, :layout => true)
        end
      end
      
      protected
      
      def tasks
        app.cache[:tasks] ||= {}
      end
      
      def app
        server.app
      end
    end
  end
end