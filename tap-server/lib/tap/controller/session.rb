module Tap
  class Controller
    
    module Session
      def self.included(mod)
        unless mod.get(:default_layout)
          mod.set(:default_layout, nil)
        end
      end
        
      # Accesses the 'tap.server' specified in env, set during call.
      attr_accessor :server
      
      def initialize(*args)
        @server = nil
        super
      end
      
      # Sets the server from the env variable 'tap.server' and calls super.
      def call(env)
        @server = env['tap.server']
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

      # Renders the specified layout with content as a local variable.  If layout
      # is true, the class default_layout will be rendered. Returns content if no
      # layout is specified.
      def render_layout(layout, content)
        if layout == true
          render(:template => self.class.get(:default_layout), :locals => {:content => content})
        else
          super
        end
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
end