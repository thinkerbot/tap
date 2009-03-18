require 'tap/controller'

module Tap
  
  #   class Projects < Tap::RestController
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
  class RestController < Controller
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
end