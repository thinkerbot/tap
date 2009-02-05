require 'tap/server'
autoload(:ERB, 'erb')

module Tap
  class Controller
    class << self
      def call(env)
        new.call(env)
      end
      
      attr_accessor :default_layout
      
      attr_writer :name
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
        @actions ||= begin
          current = public_instance_methods.collect {|method| method.to_sym }
          base = Tap::Controller.instance_methods.collect {|method| method.to_sym }
          current - base
        end
      end
    end
    
    include Rack::Utils
    
    attr_accessor :server
    attr_accessor :request
    attr_accessor :response
    
    def initialize(server=nil, request=nil, response=nil)
      @server = server
      @request = request
      @response = response
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
      action = "index" if action == nil || action.empty?
      
      unless action?(action)
        raise ServerError.new("404 Error: page not found", 404)
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
      else
        server.template_path("#{self.class.name}/#{path}")
      end
      
      unless template_path
        raise "could not find template for: #{path}"
      end
      
      template = server.content(template_path)
      content = render_erb(template, options)
      
      layout = options[:layout]
      layout = self.class.default_layout if layout == true
      if layout
        render(:template => layout, :locals => {:content => content})
      else
        content
      end
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
  end
end