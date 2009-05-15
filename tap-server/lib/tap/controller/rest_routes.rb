module Tap
  class Controller
    # Adds REST routing to a Tap::Controller.
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
    #     # POST /projects/*args
    #     def create(*args)...
    # 
    #     # PUT /projects/*args
    #     # POST /projects/*args?_method=put
    #     def update(*args)...
    # 
    #     # DELETE /projects/*args
    #     # POST /projects/*args?_method=delete
    #     def destroy(*args)...
    #
    #     # extension...
    #
    #     # POST /projects/*args?_method=another
    #     def another(*args)...
    #   end
    #
    # === Relation to RESTful Rails
    #
    # Unlike the REST syntax in Rails, '/projects/new' is treated like a show
    # where the id is 'new'.  Also missing is the routing for urls like
    # '/projects/arg;edit/'. See these resources:
    #
    # * {RESTful Rails Development}[http://www.b-simple.de/download/restful_rails_en.pdf]
    # * {REST cheatsheet}[topfunky.com/clients/peepcode/REST-cheatsheet.pdf]
    #
    module RestRoutes
      def route
        blank, *route = request.path_info.split("/").collect {|arg| unescape(arg) }
        route.unshift rest_action(route)
        route
      end
      
      def rest_action(args)
        case request.request_method
        when /GET/i
          if args.empty?
            :index
          else
            :show
          end
        when /POST/i
          case _method = request[:_method]
          when /put/i  
            :update
          when /delete/i  
            :destroy
          when nil
            :create
          else 
            if action?(_method)
              _method
            else
              raise Server::ServerError.new("unknown post method: #{_method}")
            end
          end
        when /PUT/i  then :update
        when /DELETE/i then :destroy
        else raise Server::ServerError.new("unknown request method: #{request.request_method}")
        end
      end
    end
  end
end