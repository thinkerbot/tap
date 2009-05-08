require 'tap/app/api'
require 'rack/mime'
require 'time'

module Tap
  module Controllers
    
    # :startdoc::controller remotely controls and monitors server
    # 
    # Server provides several uris to control and monitor the server behavior.
    # Importantly, server allows the remote shutdown of a Tap::Server if a
    # shutdown_key is set.  This makes it possible to run servers in the
    # background and still have a shutdown handle on them.
    #
    class Server < Tap::App::Api
      include Session
      
      set :default_layout, 'layout.erb'
        
      def index
        render('index.erb', :locals => {
          :env => server.env
        }, :layout => true)
      end
      
      # Returns the public server configurations as xml.
      def config(secret=nil)
        response['Content-Type'] = 'text/xml'
        if admin?(secret)
%Q{<?xml version="1.0"?>
<server>
<uri>#{uri}</uri>
<secret>#{server.secret}</secret>
</server>
}
        else
%q{<?xml version="1.0"?>
<server />
}
        end
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
      
      # ensure server methods are not added as actions
      set :define_action, false
      set :default_action, :index
      
      def call(env)
        # serve public files before actions
        server = env['tap.server'] ||= Tap::Server.new
    
        if path = server.path(:public, env['PATH_INFO'])
          content = File.read(path)
          headers = {
            "Last-Modified" => File.mtime(path).httpdate,
            "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
            "Content-Length" => content.size.to_s
          }
      
          [200, headers, [content]]
        else
          super
        end
      end
      
      # Returns true if input is equal to the server secret, if a secret is
      # set.  Required to test if remote administration is allowed.
      def admin?(input)
        server.secret != nil && input == server.secret
      end
      
      # Returns a controller uri, attaching the secret to the action, if specified.
      def uri(action=nil, params={})
        secret = params.delete(:secret)
        action = "#{action}/#{secret}" if secret
        super(action, params)
      end
      
      # Stops the server.
      def stop!
        server.stop!
      end
    end
  end
end