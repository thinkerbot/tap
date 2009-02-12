require 'tap/server'
autoload(:ERB, 'erb')

module Tap
  
  # === Declaring Actions
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
        child.set(:actions, actions.dup)
        child.set(:middleware, middleware.dup)
        child.set(:default_layout, default_layout)
        child.set(:define_action, true)
      end
      
      # An array of methods that can be called as actions.  Actions must be
      # stored as symbols.  Actions are inherited.
      attr_reader :actions
      
      # An array of Rack middleware that will be applied when handing requests
      # through the class call method.  Middleware is inherited.
      attr_reader :middleware
      
      # The default layout rendered when the render option :layout is true.
      attr_reader :default_layout
      
      # The base path prepended to render paths (ie render(<path>) renders
      # <templates_dir/name/path>).
      def name
        @name ||= to_s.underscore
      end
      
      # Adds the specified middleware.  Middleware classes are initialized
      # with the specified args and block, and applied to in the order in
      # which they are declared (ie first use processes requests first).
      #
      # Middleware is applied through the class call method, and on a per-call
      # basis... middleware like Rack::Session::Pool that is supposed to
      # persist for the life of an application will not work properly.
      # 
      # Middleware is inherited.
      def use(middleware, *args, &block)
        @middleware << [middleware, args, block]
      end
      
      # Instantiates self and performs call.  Middleware is applied in the
      # order in which it was declared.
      #--
      # Note that middleware needs to be initialized in reverese, so that
      # the first declared middleware runs first.
      def call(env)
        app = new
        middleware.reverse_each do |(m, args, block)|
          app = m.new(app, *args, &block)
        end
        app.call(env)
      end
      
      # Sets an instance variable for self, short for:
      #
      #   instance_variable_set(:@attribute, input)
      #
      # Typically only these variables should be set:
      #
      #   actions:: sets actions
      #   name:: the name of the controller
      #   default_layout:: the default layout (used by render)
      #
      def set(variable, input)
        instance_variable_set("@#{variable}", input)
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
    
    set :actions, []
    set :middleware, []
    set :default_layout, nil
    set :define_action, false
    
    include Rack::Utils
    
    # Accesses the 'tap.server' specified in env, set during call.
    attr_accessor :server
    
    # A Rack::Request wrapping env, set during call.
    attr_accessor :request
    
    # A Rack::Response.  If the action returns a string, it will be written to
    # response and response will be returned by call.  Otherwise, call returns
    # the action result and response is ignored.
    attr_accessor :response
    
    # Initializes a new instance of self.  The input attributes are reset by
    # call and are only provided for convenience during testing.
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
      
      # render template
      template = server.content(template_path)
      content = render_erb(template, options)
      
      # render layout
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
    
    # Redirects to the specified uri.
    def redirect(uri, status=302, headers={}, body="")
      response.status = status
      response.headers.merge!(headers)
      response.body = body
      
      response['Location'] = uri
      response.finish
    end
    
    # Returns a session hash.
    def session
      request.env['rack.session'] ||= {}
    end
    
    # Returns the app for the current session.
    def app
      server.app(session[:id] ||= server.initialize_session)
    end
    
    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
  end
end