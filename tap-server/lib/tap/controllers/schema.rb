require 'tap/controller'

module Tap
  module Controllers
    
    # ::controller
    class Schema < Tap::Controller
      include RestRoutes

      set :default_layout, 'layout.erb'
      
      # GET /projects
      def index
        render 'index.erb', :locals => {
          :schema => persistence.index(:schema)
        }, :layout => true
      end
      
      # GET /projects/id
      def show(id=persistence.next_id(:schema))
        extname = File.extname(id)
        id = id.chomp(extname)
        schema = if path = persistence.find(:schema, id)
          Tap::Schema.load_file(path)
        else
          Tap::Schema.new
        end
        
        case extname
        when '.txt'
          response.headers['Content-Type'] = 'text/plain'
          schema.dump
        when '.yml'
          response.headers['Content-Type'] = 'text/plain'
          response['Content-Disposition'] = "attachment; filename=#{id}.yml;"
          schema.dump
        else
          render 'schema.erb', :locals => {
            :id => id,
            :schema => schema
          }, :layout => true
        end
      end
      
      # POST /projects/*args
      def create(id)
        schema = Tap::Schema.new(request['schema'] || {})
        persistence.create(:schema, id) {|io| io << schema.dump }
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
        persistence.destroy(:schema, id)
        redirect uri
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      # Renames id to request['name'] in the schema persistence.
      def rename(id)
        new_id = request['name'].to_s.strip
        if new_id.empty?
          raise "no name specified"
        end
        
        content = persistence.read(:schema, id)
        persistence.destroy(:schema, id)
        persistence.create(:schema, new_id) {|io| io << content }
        
        redirect uri(new_id)
      end
      
      ############################################################
      # Helper Methods
      ############################################################
      protected
      
      def persistence
        server.persistence
      end
    end
  end
end