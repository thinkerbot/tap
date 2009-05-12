require 'tap/controllers/persistence'

module Tap
  module Controllers
    # ::controller
    class Data < Persistence
      set :default_layout, 'layout.erb'
      
      # POST /projects/*args
      def create(id=nil)
        if request.form_data?
          persistence.import(type, request[type], id)
        else
          id = persistence.next_id
          persistence.create(type, id) {|io| io << request[type] }
        end
        
        redirect uri(id)
      end
      
      # PUT /projects/*args
      # POST /projects/*args?_method=put
      def update(*args)
        unless action = request['_action']
          raise ServerError, "no action specified" 
        end
        
        action = action.to_sym
        unless action?(action)
          raise ServerError, "unknown action: #{action}"
        end
        
        send(action, *args)
      end
      
      # DELETE /projects/*args
      # POST /projects/*args?_method=delete
      def destroy(id)
        delete(id)
        redirect uri
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      def browse
        ids = request['ids']
        
        case request['action']
        when 'rename'
          case ids.length
          when 0 then raise "no entry selected for rename"
          when 1 then rename(ids[0], request['new_id'])
          else raise "multiple entries selected for rename"
          end
        when 'duplicate'
          ids.each {|id| duplicate(id) }
        when 'delete'
          ids.each {|id| delete(id) }
        else
          raise "unknown browse action: #{request['action']}"
        end
        
        redirect uri
      end
      
      # Renames id to request['name'] in the schema persistence.
      def rename(id, new_id)
        result = duplicate(id, new_id)
        persistence.destroy(type, id)
        
        result
      end
      
      # Duplicates id to request['id'] in the schema persistence.
      def duplicate(id, new_id=nil)
        new_id = "#{id}_copy" unless new_id
        check_id(new_id)
        
        persistence.create(type, new_id) do |io| 
          io << persistence.read(type, id)
        end
        
        redirect uri(new_id)
      end
      
      def delete(id)
        persistence.destroy(type, id)
      end
      
      protected
      
      def type
        :data
      end
    end
  end
end