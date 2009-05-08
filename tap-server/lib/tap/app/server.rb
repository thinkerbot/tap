require 'tap/app/api'

module Tap
  class App
    class Server < Api
      include Tap::Server::Base
      
      # ensure server methods are not added as actions
      set :define_action, false
      
      config_attr :views_dir, nil do |input|     # the views directory
        @views_dir = (input || "views/#{self.class.to_s.underscore}")
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
        super view_path(path), options
      end
      
      def view_path(path)
        File.join(views_dir, path)
      end

      # Returns a uri, with the secret if specified
      def uri(action=nil, params={})
        action = action.to_s
        "#{action[0] == ?/ ? '' : '/'}#{action}#{params[:secret] ? '/' : ''}#{params[:secret]}" 
      end
    end
  end
end