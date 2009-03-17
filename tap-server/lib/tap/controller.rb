require 'tap/server'
require 'tap/support/persistence'
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
        child.set(:default_layout, default_layout)
        child.set(:define_action, true)
        child.set(:rest_action, rest_action)
      end
      
      # An array of methods that can be called as actions.  Actions must be
      # stored as symbols.  Actions are inherited.
      attr_reader :actions
      
      # The default layout rendered when the render option :layout is true.
      attr_reader :default_layout
      
      # An action routed with RESTful routes.  For example if rest_action
      # is :projects then:
      #
      #   class RESTController < Tap::Controller
      #     set :rest_action, :projects
      #   
      #     # GET /projects
      #     def index...
      # 
      #     # GET /projects/*args
      #     def show(*args)...
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
      # May be nil to indicate no RESTful routing, and must be a symbol if set.
      attr_reader :rest_action
      
      # The base path prepended to render paths (ie render(<path>) renders
      # <templates_dir/name/path>).
      def name
        @name ||= to_s.underscore
      end
      
      # Instantiates self and performs call.
      def call(env)
        new.call(env)
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
      
      # Sets :rest_action assuring that action is symbolized.  By default
      # use_rest_routes sets the rest action to the underscored constant
      # name (ie Example => 'example').
      def use_rest_routes(action=File.basename(name))
        set :rest_action, action.to_sym
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
    set :rest_action, nil
    
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
      action = action.chomp(File.extname(action)).to_sym
      
      case
      when self.class.actions.include?(action)
      when self.class.rest_action == action
        action = case request.request_method
        when /GET/i  
          case
          when args.empty?
            :index
          when args[-1] =~ /(.*);edit$/
            args[-1] = $1
            :edit
          else 
            :show
          end
        when /POST/i then :create
        when /PUT/i  then :update
        when /DELETE/i then :destroy
        else raise ServerError.new("unknown request method: #{request.request_method}")
        end
      else
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
        server.search(:views, options[:template])
      else
        server.search(:views, "#{self.class.name}/#{path}")
      end
      
      unless template_path
        raise "could not find template for: #{path}"
      end
      
      # render template
      template = File.read(template_path)
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
      server.uri(self.class.name, action, params)
    end
    
    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
  end
end