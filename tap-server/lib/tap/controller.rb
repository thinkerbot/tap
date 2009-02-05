require 'tap/server'
autoload(:ERB, 'erb')

module Tap
  class Controller
    class << self
      def call(env)
        new.call(env)
      end
      
      def name
        @name ||= to_s.underscore.chomp("_controller")
      end
      
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
    
    attr_accessor :server
    attr_accessor :request
    attr_accessor :response
    
    def initialize
      @server = @request = @response = nil
    end
    
    def action?(action)
      action ? self.class.actions.include?(action.to_sym) : false
    end
    
    def call(env)
      @server = env['tap.server'] || Tap::Server.new
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
    
    def render(path, options={})
      options, path = path, nil if path.kind_of?(Hash)
      
      # lookup template
      template_path = case
      when options.has_key?(:template)
        server.template_path(options[:template])
      when File.file?(path) 
        path
      else
        server.template_path("#{self.class.name}/#{path}")
      end
      
      unless template_path
        raise "could not find template for: #{path}"
      end
      
      template = server.content(template_path)
      render_erb(template, options)
    end
    
    def render_erb(template, options={})
      # assign locals to the render binding
      # this almost surely may be optimized...
      locals = options[:locals]
      binding = empty_binding
      
      locals.each_pair do |key, value|
        @assignment_value = value
        eval("#{key} = remove_instance_variable(:@assignment_value)", binding)
      end if locals
      
      ERB.new(template, nil, "<>").result(binding)
    end
    
    private
    
    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
    
    # An array of methods that are not valid actions.
    NON_ACTIONS = instance_methods.collect {|method| method.to_sym }
  end
end