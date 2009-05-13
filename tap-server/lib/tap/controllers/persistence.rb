require 'tap/controller'

module Tap
  module Controllers
    class Persistence < Tap::Controller
      include RestRoutes
      include Utils
      
      set :default_layout, 'layout.erb'
      
      # GET /projects
      def index
        render 'index.erb', :locals => {
          type => data.index(type)
        }, :layout => true
      end
      
      # GET /projects/id
      def show(id)
        static_file(data.find(type, id))
      end
      
      # POST /projects/*args
      def create(id)
        data.create(type, id) {|io| io << request[type] }
        redirect uri(id)
      end
      
      # PUT /projects/*args
      # POST /projects/*args?_method=put
      def update(id)
        unless action = request['_action']
          raise ServerError, "no action specified" 
        end
        
        action = action.to_sym
        unless action?(action)
          raise ServerError, "unknown action: #{action}"
        end
        
        send(action, *id)
      end
      
      # DELETE /projects/*args
      # POST /projects/*args?_method=delete
      def destroy(id)
        data.destroy(type, id)
        redirect uri
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      # Renames id to request['name'] in the schema data.
      def rename(id)
        result = duplicate(id)
        data.destroy(type, id)
        
        result
      end
      
      # Duplicates id to request['id'] in the schema data.
      def duplicate(id)
        new_id = request['id'].to_s.strip
        check_id(new_id)
        
        data.create(type, new_id) do |io| 
          io << data.read(type, id)
        end
        
        redirect uri(new_id)
      end
      
      protected # Helper Methods
      
      def type
        request[:type]
      end
      
      def check_id(id)
        raise "empty id specified" if id == ""
      end
      
      def data
        server.data
      end
    end
  end
end