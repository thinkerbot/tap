require 'tap/server'
autoload(:ERB, 'erb')

module Tap
  class Controller
    
    module Base
      include Rack::Utils
      ServerError = Tap::Server::ServerError

      # A Rack::Request wrapping env, set during call.
      attr_accessor :request

      # A Rack::Response.  If the action returns a string, it will be written to
      # response and response will be returned by call.  Otherwise, call returns
      # the action result and response is ignored.
      attr_accessor :response
      
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
        unless actions.include?(action)
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
        action = default_action if action == nil || action.empty?

        [action.to_sym, args]
      end

      # Renders the path with the specified options.  Options:
      #
      #   layout:: renders with the specified layout, or default_layout if true
      #   locals:: a hash of local variables used in the template
      #
      def render(path, options={})
        # render template
        template = File.read(path)
        content = render_erb(template, options, path)

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

      # Generates an empty binding to self without any locals assigned.
      def empty_binding # :nodoc:
        binding
      end
    end
  end
end