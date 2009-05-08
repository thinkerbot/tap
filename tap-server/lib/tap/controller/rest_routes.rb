module Tap
  class Controller
    # Adds REST routing (a-la Rails) to a Tap::Controller.
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
    #     # POST /projects/*args?_method=put
    #     def update(*args)...
    # 
    #     # DELETE /projects/*args
    #     # POST /projects/*args?_method=delete
    #     def destroy(*args)...
    #   end
    #
    # Note the syntax '/projects/new' is treated like a show where the id is
    # 'new'.  This is different from the Rails behavior.  See these resources:
    #
    # * {RESTful Rails Development}[http://www.b-simple.de/download/restful_rails_en.pdf]
    # * {REST cheatsheet}[topfunky.com/clients/peepcode/REST-cheatsheet.pdf]
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
        when /POST/i
          case request[:_method]
          when /put/i  
            :update
          when /delete/i  
            :destroy
          else 
            :create
          end
        when /PUT/i  then :update
        when /DELETE/i then :destroy
        else raise Server::ServerError.new("unknown request method: #{request.request_method}")
        end

        [action, args]
      end
    end
  end
end