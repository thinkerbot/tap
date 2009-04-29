require 'tap/server'
require 'tap/server/persistence'
autoload(:ERB, 'erb')

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
    
    # Adds REST routing (a-la Rails[http://www.b-simple.de/download/restful_rails_en.pdf])
    # to a Tap::Controller.
    #
    #   class Projects < Tap::Controller
    #     include RestRoutes
    #
    #     # GET /projects
    #     def index...
    # 
    #     # GET /projects/*args
    #     def show(*args)...
    # 
    #     # GET /projects/arg;edit/*args
    #     def edit(arg, *args)...
    #
    #     # POST /projects/*args
    #     def create(*args)...
    # 
    #     # PUT /projects/*args
    #     def update(*args)...
    # 
    #     # DELETE /projects/*args
    #     def destroy(*args)...
    #   end
    #
    module RestRoutes
      def route
        blank, *args = request.path_info.split("/").collect {|arg| unescape(arg) }
        action = case request.request_method
        when /GET/i  
          case
          when args.empty?
            :index
          when args[0] =~ /(.*);edit$/
            args[0] = $1
            :edit
          else 
            :show
          end
        when /POST/i then :create
        when /PUT/i  then :update
        when /DELETE/i then :destroy
        else raise ServerError.new("unknown request method: #{request.request_method}")
        end

        [action, args]
      end
    end
        
    class << self
      
      # Initialize instance variables on the child and inherit as necessary.
      def inherited(child) # :nodoc:
        super
        child.set(:actions, actions.dup)
        child.set(:default_action, default_action)
        child.set(:default_layout, default_layout)
        child.set(:define_action, true)
      end
      
      # An array of methods that can be called as actions.  Actions must be
      # stored as symbols.  Actions are inherited.
      attr_reader :actions
      
      # The default action called for the request path '/'
      attr_reader :default_action
      
      # The default layout rendered when the render option :layout is true.
      attr_reader :default_layout
      
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
    set :default_layout, nil
    set :default_action, :index
    
    # Ensures methods (even public methods) on Controller will
    # not be actions in subclasses. 
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
    
    # Initializes a new instance of self.
    def initialize(app=nil)
      @server = @request = @response = nil
      @app = app
    end
    
    # Routes the request to an action and returns the response.  Routing is
    # simple and fixed (see route):
    #
    #   route                  calls
    #   /                      default_action (ie 'index')
    #   /action/*args          action(*args)
    #
    # Call sets up instance variables that may be used in the action:
    #
    #   server:: the Tap::Server specified in the env, or a new Tap::Server
    #   request: a Rack::Request for env
    #   response:: a Rack::Response
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
      @server = env['tap.server'] || Tap::Server.new
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      
      # route to an action
      action, args = route
      unless self.class.actions.include?(action)
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
      blank, action, *args = request.path_info.split("/").collect {|arg| unescape(arg) }
      action = self.class.default_action if action == nil || action.empty?

      [action.to_sym, args]
    end
    
    # Looks up a template associated with the class of obj, ie:
    #
    #   <views>/class_file_path/path
    #
    # The default class_file_path is 'obj.class.to_s.underscore', but classes
    # can specify an alternative by providing a class_file_path method.
    #
    # If the specified path cannot be found, class file searches the superclass
    # of obj.class.  Returns nil if no file can be found for any class in the
    # inheritance hierarchy.
    #
    def class_path(path, obj=self)
      server.class_path(:views, obj, path)
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
        server.path(:views, options[:template])
      else
        class_path(path)
      end
      
      unless template_path
        raise "could not find template for: #{path}"
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
      case layout
      when nil  
        return content
      when true 
        layout = self.class.default_layout 
      end
      
      render(:template => layout, :locals => {:content => content})
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
      binding = empty_binding
      
      locals.each_pair do |key, value|
        @assignment_value = value
        eval("#{key} = remove_instance_variable(:@assignment_value)", binding)
      end if locals
      
      erb = ERB.new(template, nil, "<>")
      erb.filename = filename
      erb.result(binding)
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
    
    # Returns the root for the current session.
    def root
      server.root(session[:id] ||= server.initialize_session)
    end
    
    # Returns the file-based controller persistence.
    def persistence
      @persistence ||= Support::Persistence.new(root)
    end
    
    # Returns a controller uri.
    def uri(action=nil, params={})
      server.uri(self.class.to_s.underscore, action, params)
    end
    
    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
  end
end