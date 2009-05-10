require 'tap/controller'

module Tap
  module Controllers
    
    # :startdoc::controller builds and runs workflows
    class App < Tap::Controller
      set :default_action, :info
      
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
          Thread.new { app.run }
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
        unless request.post?
          return render('build.erb', :layout => true)
        end
        
        schema = if request[:parse] == "on"
          Tap::Schema.parse(request[:schema])
        else
          Tap::Schema.load(request[:schema])
        end
        
        app.cache[:tasks] = server.env.build(schema, app)
        
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
      
      def tail(id)
        unless persistence.has?("#{id}.log")
          raise Tap::ServerError.new("invalid id: #{id}", 404)
        end
        
        path = persistence.path("#{id}.log")
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
      
      def app
        server.app
      end
    end
  end
end