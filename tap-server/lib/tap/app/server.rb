require 'tap/app/api'
require 'tap/server/base'

module Tap
  class App
    class Server < Api
      include Tap::Server::Base
      
      # Essentially a login for server administration
      def access
        if request.get?
          render 'access.erb', :locals => {:secret => request['secret']}, :layout => true
        else
          redirect uri("admin/#{request['secret']}")
        end
      end
      
      # Administrate this server
      def admin(secret=nil)
        template = admin?(secret) ? 'admin.erb' : 'access.erb'
        render template, :locals => {:secret => secret}, :layout => true
      end
      
      # Returns the pid if the correct secret is provided
      def pid(secret=nil)
        response['Content-Type'] = "text/plain"
        
        return "" unless admin?(secret)
        Process.pid.to_s
      end
      
      # Terminates app and stops self (on post).
      def shutdown(secret=nil)
        response['Content-Type'] = "text/plain"
        
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
      
      config_attr :views_dir, nil do |input|     # the views directory
        @views_dir = (input || "views/tap/app/server")
      end
      
      def initialize(config={}, app=Tap::App.new)
        super(app)
        initialize_config(config)
      end
      
      def call(env)
        super(env)
      rescue ServerError
        $!.response
      rescue Exception
        ServerError.response($!)
      end
      
      def render(path, options={})
        # render relative to view path
        super view_path(path), options
      end
      
      def render_layout(layout, content)
        # no layouts
        content
      end
      
      def view_path(path)
        view_path = File.join(views_dir, path)
        File.file?(view_path) ? view_path : File.join(DEFAULT_API_VIEWS_DIR, path)
      end

      # Returns a uri, with the secret if specified
      def uri(action=nil, params={})
        action = action.to_s
        
        # add / before action to make all paths relative to host
        "#{action[0] == ?/ ? '' : '/'}#{action}#{params[:secret] ? '/' : ''}#{params[:secret]}" 
      end
    end
  end
end