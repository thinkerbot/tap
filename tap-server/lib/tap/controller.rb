require 'tap/server'
require 'tap/controller/session'
require 'tap/controller/rest_routes'

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
    class << self

      # Initialize instance variables on the child and inherit as necessary.
      def inherited(child) # :nodoc:
        super
        
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
    
    include Rack::Utils
    ServerError = Tap::Server::ServerError
    
    set :actions, []
    set :default_action, :index

    #--
    # Ensures methods (even public methods) on Controller will
    # not be actions in subclasses. 
    set :define_action, false
    
    # A Rack::Request wrapping env, set during call.
    attr_accessor :request

    # A Rack::Response.  If the action returns a string, it will be written to
    # response and response will be returned by call.  Otherwise, call returns
    # the action result and response is ignored.
    attr_accessor :response
    
    # Initializes a new instance of self.
    def initialize
      @request = @response = nil
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
    
    # Renders the class_file at path with the specified options.  Path can be
    # omitted if options specifies an alternate path to render.  Options:
    #
    #   layout:: renders with the specified layout
    #   locals:: a hash of local variables used in the template
    #
    def render(path, options={})
      # render template
      template = File.read(path)
      content = render_erb(template, options, path)
      
      # render layout
      render_layout(options[:layout], content)
    end

    # Renders the specified layout with content as a local variable.  Returns
    # content if no layout is specified.
    def render_layout(layout, content)
      return content unless layout
      render(layout, :locals => {:content => content})
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

      response['Location'] = [uri]
      response.finish
    end

    # Generates an empty binding to self without any locals assigned.
    def empty_binding # :nodoc:
      binding
    end
  end
end