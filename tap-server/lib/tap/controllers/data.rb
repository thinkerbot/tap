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
        if id == "new"
          return render('_new.erb')
        end
        
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
      # POST /projects?type=
      def create(id=nil)
        check_id(id)
        
        if request.media_type == 'multipart/form-data'
          data.import(type, request[type], id)
        else
          id ||= data.next_id
          data.create(type, id) {|io| io << request[type] }
        end
        
        redirect uri
      end
      
      # PUT /projects/id
      # POST /projects/id?_method=put&_action=select
      # POST /projects?_method=put&_action=select&id=id
      def update(id)
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
        data.destroy(type, id)
        redirect uri
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      # POST /projects?_method=put&_action=batch&id[]=id
      def batch(ids)
        unless ids.kind_of?(Array)
          ids = [ids].compact
        end
        
        case request['_batch']
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
        redirect data.move(type, id, request['new_id'])
      end
      
      # Duplicates id to request['id'] in the schema data.
      def duplicate(id)
        redirect data.copy(type, id, request['new_id'] || "#{id}_copy")
      end
      
      # Helper methods
      set :define_action, false
      
      def type
        :data
      end
      
      def data
        server.data
      end
      
      def dispatch(action, args)
        if args.empty?
          if id = request['id']
            args << id
          end 
        else
          args = [File.join(*args)] 
        end
        
        super
      end
      
      def check_id(id)
        if id == "new"
          raise "reserved id: #{id.inspect}"
        end
      end
    end
  end
end