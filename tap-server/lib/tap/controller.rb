require 'rack'
require 'tap'
require 'tap/server_error'

module Tap
  class Controller
    class << self
      attr_writer :actions
      
      # An array of valid actions for self.  Actions are by default all public
      # instance methods, minus all methods defined by Tap::Controller (ie all
      # public methods defined by a subclass).
      #
      # The actions array is cached, but may be reset when new methods are
      # added by specifiying reset=true.
      def actions
        @actions ||= (public_instance_methods.collect {|method| method.to_sym } - NON_ACTIONS)
      end
    end
    
    include Rack::Utils
    
    attr_reader :server
    attr_reader :request
    attr_reader :response
    
    def initialize(server)
      @server = server
      @request = nil
      @response = nil
    end
    
    def action?(action)
      action ? self.class.actions.include?(action.to_sym) : false
    end
    
    def call(env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      
      # route to an action
      blank, action, *args = request.path_info.split("/").collect {|arg| unescape(arg) }
      action = "index" if action.empty?
      
      unless action?(action)
        raise ServerError.new("404 Error: unknown action", 404)
      end
      
      response.write send(action, *args).to_s
      response.finish
    end
    
    def render(thing, options={})
    end
    
    def redirect(method, url)
      @server.redirect(method, url)
    end
    
    # An array of methods that are not valid actions.
    NON_ACTIONS = instance_methods.collect {|method| method.to_sym }
  end
end