require 'rack'
require 'rack/mime'
require 'time'
require 'tap/server_error'
require 'tap/support/renderer'

module Tap
  class Controller    
    class << self
      def call(env)
        # route the path
        env['PATH_INFO'] =~ /^\/([^\/]+)/
        action = $1 || default_action
        unless public_instance_methods.include?(action)
          action = unknown_action
        end
        
        # handle the request
        req = Rack::Request.new(env)
        res = Rack::Response.new
        res.write new(req, res).send(action).to_s
        res.finish
      end
      
      # Returns the method called when no action is specified,
      # by default :index.
      def default_action
        @default_action ||= 'index'
      end
      
      # Sets default_action.
      def set_default_action(input)
        @default_action = input
      end
      
      # Returns the method called when an action is unknown,
      # by default :unknown.
      def unknown_action
        @unknown_action ||= 'unknown'
      end
      
      # Sets unknown_action.
      def set_unknown_action(input)
        @unknown_action = input
      end
    end
    
    def initialize(req, res)
      @req = req
      @res = res
      @server = req.env['tap.server']
      @env = @server.env
      @renderer = initialize_renderer
    end
    
    def unknown
      path_info = @req.path_info
      
      case
      when path = @env.search(:views, path_info) {|file| File.file?(file) }
        # serve templates
        render(path)
        
      when path = @env.search(:public, path_info) {|file| File.file?(file) }
        
        # serve static pages
        content = File.read(path)
        @res.headers.merge!(
          "Last-Modified" => File.mtime(path).httpdate,
          "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
          "Content-Length" => content.size.to_s)
          
        content
        
      else
        # missing page
        render '404.erb', :locals => {:req => @req}
      end
    end
    
    def render(thing, options={})
      @renderer.render(thing, options)
    end
    
    def partial(path, options={})
      @renderer.partial(path, options)
    end
    
    # experimental!
    def redirect(path)
      result = @server.process(path)
      @res.status = result.status
      @res.header.clear
      @res.headers.merge! result.headers
      @res.body = result.body
      
      nil
    end
    
    private
    
    def initialize_renderer
      Support::Renderer.intern do |r, thing|
        thing = thing.to_s
        
        # default to erb...
        path = File.extname(thing) == '' ? "#{thing}.erb" : thing
        
        # lookup the template path
        File.exists?(path) ? path : @env.search(:views, path, true) {|file| File.file?(file) }
      end
    end
    
  end
end