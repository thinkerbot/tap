require 'erb'
require 'tap/server'
require 'tap/controller/rest_routes'
require 'tap/controller/utils'

module Tap
  
  # === Declaring Actions
  #
  # By default all public methods in subclasses are declared as actions.  You
  # can declare a private or protected method as an action by:
  #
  # * manually adding it directly to actions
  # * defining it as a public method and then call private(:method) or protected(:method)
  #
  # Similarly, public method can be made non-action by actions by:
  #
  # * manually deleting it from actions
  # * define it private or protected then call public(:method)
  #
  class Controller
    class << self

      # Initialize instance variables on the child and inherit as necessary.
      def inherited(child) # :nodoc:
        super
        
        unless child.instance_variable_defined?(:@source_file)
          caller[0] =~ Lazydoc::CALLER_REGEXP
          child.instance_variable_set(:@source_file, File.expand_path($1)) 
        end
        
        set_variables.each do |variable|
          child.set(variable, get(variable))
        end
        
        child.set(:actions, actions.dup)
        child.set(:define_action, true)
      end

      # An array of methods that can be called as actions.  Actions must be
      # stored as symbols.  Actions are inherited.
      attr_reader :actions

      # The default action called for the request path '/'
      attr_reader :default_action
      
      # Instantiates self and performs call.
      def call(env)
        new.call(env)
      end

      # Sets an instance variable for self (ie the class), short for:
      #
      #   instance_variable_set(:@attribute, input)
      #
      # These variables are meaningful to a default Tap::Controller and will
      # be inherited by subclasses:
      #
      #   actions:: sets actions
      #   default_action:: the default action (:index)
      #
      def set(variable, input)
        set_variables << variable
        instance_variable_set("@#{variable}", input)
      end
      
      # Gets the value of an instance variable set via set.  Returns nil for
      # variables that have not been set through set.
      def get(variable)
        return nil unless set_variables.include?(variable)
        instance_variable_get("@#{variable}")
      end
      
      # An array of variables set via set.  set_variables are inherited.
      def set_variables
        @set_variables ||= []
      end
      
      def nest(key, controller, &block)
        
        # generate a subclass if anything gets overridden
        if block_given?
          controller = Class.new(controller)
          controller.class_eval(&block)
        end
        
        # this check prevents a warning in cases where the nesting 
        # class defines the nested class
        const_name = key.to_s.camelize
        unless const_defined?(const_name) && const_get(const_name) == subclass
          const_set(const_name, controller)
        end
        
        define_method(key) do |*args|
          instance = controller.new
          
          instance.server = server
          instance.controller_path = controller_path ? "#{controller_path}/#{key}" : key
          instance.request = request
          instance.response = response
          
          instance.dispatch(args)
        end
      end

      protected

      # Overridden so that if declare_action is set, new methods
      # are added to actions.
      def method_added(sym) # :nodoc:
        actions << sym if @define_action
        super
      end

      # Turns on declare_action when changing method context.
      def public(*symbols) # :nodoc:
        @define_action = true if symbols.empty?
        super
      end

      # Turns off declare_action when changing method context.
      def protected(*symbols) # :nodoc:
        @define_action = false if symbols.empty?
        super
      end

      # Turns off declare_action when changing method context.
      def private(*symbols) # :nodoc:
        @define_action = false if symbols.empty?
        super
      end
    end
    
    extend Lazydoc::Attributes
    include Rack::Utils
    ServerError = Tap::Server::ServerError
    
    lazy_attr :desc, 'controller'
    
    set :actions, []
    set :default_action, :index
    set :default_layout, 'layout.erb'
    
    #--
    # Ensures methods (even public methods) on Controller will
    # not be actions in subclasses. 
    set :define_action, false
    
    attr_accessor :server
    
    attr_accessor :controller_path
    
    # A Rack::Request wrapping env, set during call.
    attr_accessor :request

    # A Rack::Response.  If the action returns a string, it will be written to
    # response and response will be returned by call.  Otherwise, call returns
    # the action result and response is ignored.
    attr_accessor :response
    
    # Initializes a new instance of self.
    def initialize
      @request = @response = @server = @controller_path = nil
    end
    
    # Returns true if action is registered as an action for self.
    def action?(action)
      self.class.actions.include?(action.to_sym)
    end
    
    # Returns a uri to the specified action on self.
    def uri(action=nil, params={})
      uri = []
      
      if controller_path
        uri << '/'
        uri << controller_path
      end
      
      if action
        uri << '/'
        uri << action
      end
      
      unless params.empty?
        uri << '?'
        uri << build_query(params)
      end
      
      uri.join
    end
    
    def template_path(path)
      server.env.path(:views, path) {|file| File.file?(file) }
    end
    
    def module_path(path, klass=self.class)
      server.env.module_path(:views, klass.ancestors, path) {|file| File.file?(file) }
    end
    
    # Routes the request to an action and returns the response.  Routing is
    # simple and fixed (see route):
    #
    #   route                  calls
    #   /                      default_action (ie 'index')
    #   /action/*args          action(*args)
    #
    # If the action returns a string, it will be written to response.
    # Otherwise, call returns the result of action.  This allows actions like:
    #
    #   class ActionsController < Tap::Controller
    #     def simple
    #       "html body"
    #     end
    #
    #     def standard
    #       response["Content-Type"] = "text/plain"
    #       response << "text"
    #       response.finish
    #     end
    #
    #     def custom
    #       [200, {"Content-Type" => "text/plain"}, ["text"]]
    #     end
    #   end
    #
    def call(env)
      @server = env['tap.server']
      @controller_path = env['tap.controller_path']
      
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      
      case result = dispatch(route)
      when String
        response.write result
        response.finish
      when nil
        response.finish
      else 
        result
      end
    end

    # Returns the action, args, and extname for the request.path_info.  Routing
    # is simple and fixed:
    #
    #   route             returns
    #   /                 [:index, []]
    #   /action/*args     [:action, args]
    #
    # The action and args are unescaped by route.  An alternate default action
    # may be specified using set.  Override this method in subclasses for
    # fancier routes.
    def route
      blank, *route = request.path_info.split("/").collect {|arg| unescape(arg) }
      route
    end
    
    def dispatch(route)
      action, *args = route
      
      if action == nil || action == ""
        action = self.class.default_action 
      end
      
      unless action?(action)
        raise ServerError.new("404 Error: page not found", 404)
      end
      
      send(action, *args)
    end
    
    # Renders the class_file at path with the specified options.  Path can be
    # omitted if options specifies an alternate path to render.  Options:
    #
    #   template:: renders the template relative to the template directory
    #   file:: renders the specified file 
    #   layout:: renders with the specified layout, or default_layout if true
    #   locals:: a hash of local variables used in the template
    #
    def render(path, options={})
      options, path = path, nil if path.kind_of?(Hash)

      # lookup template
      template_path = case
      when options[:file]
        options[:file]
      when options[:template]
        self.template_path(options[:template])
      else
        self.module_path(path)
      end

      unless template_path
        raise "could not find template: (path: #{path.inspect}, file: #{options[:file].inspect}, template: #{options[:template].inspect})"
      end
      
      # render template
      template = File.read(template_path)
      content = render_erb(template, options, template_path)
      
      # render layout
      render_layout(options[:layout], content)
    end

    # Renders the specified layout with content as a local variable.  If layout
    # is true, the class default_layout will be rendered. Returns content if no
    # layout is specified.
    def render_layout(layout, content)
      return content unless layout
      
      if layout == true
        layout = self.class.get(:default_layout)
      end
      
      if layout.kind_of?(Hash)
        locals = layout[:locals] ||= {}
        
        if locals.has_key?(:content)
          raise "layout already has local content assigned: #{layout.inspect}"
        end
        
        locals[:content] = content
      else
        layout = {:template => layout, :locals => {:content => content}}
      end
      
      render(layout)
    end

    # Renders the specified template as ERB using the options.  Options:
    #
    #   locals:: a hash of local variables used in the template
    #
    # The filename used to identify errors in an erb template to a specific
    # file and is completely options (but handy).
    def render_erb(template, options={}, filename=nil)
      # assign locals to the render binding
      # this almost surely may be optimized...
      locals = options[:locals]
      binding = render_erb_binding

      locals.each_pair do |key, value|
        @assignment_value = value
        eval("#{key} = remove_instance_variable(:@assignment_value)", binding)
      end if locals

      erb = ERB.new(template, nil, "<>")
      erb.filename = filename
      erb.result(binding)
    end
    
    def module_render(path, obj, options={})
      obj = obj.class unless obj.kind_of?(Module)
      options[:file] = module_path(path, obj) || module_path(path)
      
      locals = options[:locals] ||= {}
      locals[:obj] ||= obj
      
      render options
    end
    
    # Redirects to the specified uri.
    def redirect(uri, status=302, headers={}, body="")
      response.status = status
      response.headers.merge!(headers)
      response.body = body

      response['Location'] = [uri]
      response.finish
    end
    
    private
    
    # Generates an empty binding to self without any locals assigned.
    def render_erb_binding # :nodoc:
      binding
    end
  end
end