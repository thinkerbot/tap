require 'tap/controller'
require 'rack/mime'
require 'time'

module Tap
  module Controllers
    
    # :startdoc::controller remotely controls and monitor a server
    # 
    # Server provides several uris to control and monitor the server behavior.
    # Importantly, server allows the remote shutdown of a Tap::Server if a
    # shutdown_key is set.  This makes it possible to run servers in the
    # background and still have a shutdown handle on them.
    #
    class Server < Tap::Controller
      include Utils
      
      def index
        env = server.env
        env_keys = env.minihash(true) 
        constants = env.constants
        manifests = env.collect do |current|
          types = {}
          constants.entries(current).minimap.each do |key, const|
            const.types.keys.each do |type|
              (types[type] ||= []) << [key, const]
            end
          end
          
          types = types.to_a.sort_by {|type, minimap| type }
          types.empty? ? nil : [env_keys[current], types]
        end 
        
        render 'index.erb', :locals => {
          :manifests => manifests.compact
        }, :layout => true
      end
      
      # Returns pong
      def ping
        response['Content-Type'] = "text/plain"
        "pong"
      end
      
      # Essentially a login for server administration
      def access
        if request.get?
          render 'access.erb', :locals => {
            :secret => request['secret']
          }, :layout => true
        else
          redirect uri("admin", :secret => request['secret'])
        end
      end
      
      # Administrate this server
      def admin(secret=nil)
        template = server.admin?(secret) ? 'admin.erb' : 'access.erb'
        render template, :locals => {:secret => secret}, :layout => true
      end
      
      # Terminates app and stops self (on post).
      def shutdown(secret=nil)
        response['Content-Type'] = "text/plain"
        
        if server.admin?(secret) && request.post?
          # wait a bit to shutdown, so the response is sent out.
          Thread.new { sleep(0.1); server.stop! }
          "shutdown"
        else
          ""
        end
      end
      
      def help(*key)
        if constant = server.env[key.join('/')]
          path = server.module_path('help.erb', constant)
          render :file => path, :locals => {:obj => constant}
        else
          "unknown constant: #{key.join('/')}"
        end
      end
      
      # ensure server methods are not added as actions
      set :define_action, false
      
      def call(rack_env)
        server = rack_env['tap.server']
        env = server ? server.env : nil
        path_info = rack_env['PATH_INFO']
        
        # serve static files
        path = env.path(:public, path_info) {|file| File.file?(file) }
        return static_file(path) if path
        
        # route to a controller
        blank, path, path_info = path_info.split("/", 3)
        constant = env ? env.constants.seek(unescape(path)) : nil

        if constant
          # adjust rack_env if route routes to a controller
          rack_env['SCRIPT_NAME'] = "#{rack_env['SCRIPT_NAME'].chomp('/')}/#{path}"
          rack_env['PATH_INFO'] = "/#{path_info}"

          constant.unload if server.development
          controller = constant.constantize
          controller == Server ? super : controller.call(rack_env)
        else
          response = Rack::Response.new
          response.status = 302
          response['Location'] = ["/server#{rack_env['PATH_INFO']}".chomp("/")]
          response.finish
        end
      end
      
      # Returns a controller uri, attaching the secret to the action, if specified.
      def uri(action=nil, params={})
        secret = params.delete(:secret)
        
        if secret
          action = action ? "#{action}/#{secret}" : secret
        end
        
        super(action, params)
      end
      
      # Returns a help uri for the specified resource, currently only sketched out.
      def help_uri(key)
        uri("help/#{key}")
      end
      
      def template
        %Q{<% if !minimap.empty? && count > 1 %>
  <h2><%= env_key %></h2>
  <li>
    <ul><% minimap.each do |key, entry| %>
    <li><%= key %> (<a href="help/<%= key %>">?</a>)</li><% end %>
    </ul>
  </li>
<% end %>}
      end
    end
  end
end