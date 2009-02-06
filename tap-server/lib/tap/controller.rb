require 'tap/server'
autoload(:ERB, 'erb')

module Tap
  class Controller
    class << self
      
      def inherited(child)
        super
        child.set(:actions, actions.dup)
        child.set(:middleware, middleware.dup)
        child.set(:default_layout, default_layout)
        child.set(:define_action, true)
      end
      
      attr_reader :actions
      
      attr_reader :middleware
      
      attr_reader :default_layout
      
      def name
        @name ||= to_s.underscore.chomp("_controller")
      end
      
      def use(middleware, *args, &block)
        @middleware << [middleware, args, block]
      end
      
      def call(env)
        app = new
        middleware.reverse_each do |(m, args, block)|
          app = m.new(app, *args, &block)
        end
        app.call(env)
      end
      
      def set(attribute, input)
        instance_variable_set("@#{attribute}", input)
      end
      
      protected
      
      def method_added(sym)
        actions << sym if @define_action
        super
      end
      
      def public(*symbols)
        @define_action = true if symbols.empty?
        super
      end
      
      def protected(*symbols)
        @define_action = false if symbols.empty?
        super
      end
      
      def private(*symbols)
        @define_action = false if symbols.empty?
        super
      end
    end
    
    set :actions, []
    set :middleware, []
    set :default_layout, nil
    set :define_action, false
    
    include Rack::Utils
    
    attr_accessor :server
    attr_accessor :request
    attr_accessor :response
    
    def initialize(server=nil, request=nil, response=nil)
      @server = server
      @request = request
      @response = response
    end
    
    def call(env)
      @server = env['tap.server'] || Tap::Server.new
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      
      # route to an action
      blank, action, *args = request.path_info.split("/").collect {|arg| unescape(arg) }
      action = "index" if action == nil || action.empty?
      
      unless self.class.actions.include?(action.to_sym)
        raise ServerError.new("404 Error: page not found", 404)
      end
      
      result = send(action, *args)
      if result.kind_of?(String) 
        response.write result
        response.finish
      else 
        result
      end
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
    
    def redirect(uri, opts={})
      uri = URI(uri)
      
      env = request.env.dup
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = (!uri.path || uri.path.empty?) ? "/" : uri.path
      env.merge!(opts)
      
      server.call(env)
    end
    
    private
    
    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
  end
end