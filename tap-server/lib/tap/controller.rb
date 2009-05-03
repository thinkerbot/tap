require 'tap/controller/base'
require 'tap/controller/rest_routes'

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
    include Base
    
    set :actions, []
    set :default_layout, nil
    set :default_action, :index

    # Ensures methods (even public methods) on Controller will
    # not be actions in subclasses. 
    set :define_action, false
    
    # Accesses the 'tap.server' specified in env, set during call.
    attr_accessor :server
    
    # Initializes a new instance of self.
    def initialize(app=nil)
      @server = @request = @response = nil
      @app = app
    end
    
    def actions
      self.class.actions
    end
    
    def default_action
      self.class.default_action
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
      @server = env['tap.server'] || Server.new
      super(env)
    end
    
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
      
      super(template_path, options)
    end
    
    # Returns a session hash.
    def session
      request.env['rack.session'] ||= {:id => server.initialize_session}
    end
    
    # Returns the app for the current session.
    def app
      server.session(session[:id]).app
    end
    
    # Returns the persistence for the current session.
    def persistence
      server.session(session[:id]).persistence
    end
    
    # Returns a controller uri.
    def uri(action=nil, params={})
      server.uri(self.class.to_s.underscore, action, params)
    end
  end
end