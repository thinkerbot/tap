require 'tap/controller'

module Tap
  module Controllers
    # ::controller
    class Data < Tap::Controller
      include RestRoutes
      include Utils
      
      set :default_layout, 'layout.erb'
      
      # GET /projects
      def index
        render 'index.erb', :layout => true
      end
      
      # GET /projects/id
      # GET /projects?id=id
      def show(id)
        id ||= request['id']
        
        unless path = data.find(type, id)
          raise "unknown #{type}: #{id.inspect}"
        end
        
        if request['download'] == "on"
          static_file(path)
        else
          render 'preview.erb', :locals => {
            :id => id,
            :content => data.read(type, id)
          }
        end
      end
      
      # POST /projects/id
      # POST /projects?id=id
      def create(id=nil)
        if request.form_data?
          data.import(type, request[type], id)
        else
          id ||= request['id'] || data.next_id
          data.create(type, id) {|io| io << request[type] }
        end
        
        redirect uri(id)
      end
      
      # PUT /projects/id
      # POST /projects/id?_method=put&_action=select
      # POST /projects?_method=put&_action=select&id=id
      def update(id=nil)
        id ||= request['id']
        
        unless action = request['_action']
          raise ServerError, "no action specified" 
        end
        
        action = action.to_sym
        unless action?(action)
          raise ServerError, "unknown action: #{action}"
        end
        
        send(action, id)
      end
      
      # DELETE /projects/id
      # POST /projects/id?_method=delete
      # POST /projects?_method=put&id=id
      def destroy(id)
        id ||= request['id']
        
        data.destroy(type, id)
        redirect uri
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      def batch_update(ids)
        ids = [ids].compact unless ids.kind_of?(Array)
        
        case request['_batch_action']
        when 'duplicate'
          ids.each {|id| data.copy(type, id, "#{id}_copy") }
        when 'delete'
          ids.each {|id| data.destroy(type, id) }
        else
          raise "unknown batch action: #{request['action']}"
        end
        
        redirect uri
      end
      
      # Renames id to request['name'] in the schema data.
      def rename(id)
        data.mv(:data, id, request['new_id'])
      end
      
      # Duplicates id to request['id'] in the schema data.
      def duplicate(id)
        data.copy(:data, id, request['new_id'] || "#{id}_copy")
      end
      
      protected # Helper Methods
      
      def type
        request[:type] || :data
      end
      
      def data
        server.data
      end
      
      def route
        action, args = super
        [action, File.join(*args)]
      end
    end
  end
end