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
        
        schema = load_schema(id).resolve! do |type, key, data|
          env.constant_manifest(type)[key]
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
        result = duplicate(id)
        persistence.destroy(:schema, id)
        
        result
      end
      
      # Duplicates id to request['name'] in the schema persistence.
      def duplicate(id)
        new_id = request['name'].to_s.strip
        if new_id.empty?
          raise "no name specified"
        end
        
        if new_id == id
          raise "same name specified"
        end
        
        persistence.create(:schema, new_id) do |io| 
          io << persistence.read(:schema, id)
        end
        
        redirect uri(new_id)
      end
      
      # Adds tasks or joins to the schema.  Parameters:
      #
      # tasks[]::   An array of tasks to add to the schema.
      # inputs[]::  An array of task indicies used as inputs to a join.
      # outputs[]:: An array of task indicies used as outputs for a join.
      #
      def add(id)
        tasks = request['tasks'] || []
        inputs = request['inputs'] || []
        outputs = request['outputs'] || []
        queue = request['queue'] || []
        
        update_schema(id) do |schema|
          current = schema.tasks
          tasks.each do |task|
            key = current.length
            key += 1 while current.has_key?(key.to_s)
            
            current[key.to_s] = {'id' => task}
          end
          
          if !inputs.empty? && !outputs.empty?
            schema.joins << [inputs, outputs]
          end
          
          queue.each do |task|
            schema.queue << [task]
          end
        end
        
        redirect uri(id)
      end
      
      # Removes tasks or joins from a schema.  Parameters:
      #
      # tasks[]:: An array of task keys to remove.
      # joins[]:: An array of join indicies to remove.
      #
      def remove(id)
        tasks = request['tasks'] || []
        joins = request['joins'] || []
        queue = request['queue'] || []
        
        update_schema(id) do |schema|
          tasks.each do |key|
            schema.tasks.delete(key)
          end
          
          joins.each {|index| schema.joins[index.to_i] = nil }
          schema.joins.compact!
          
          queue.each {|index| schema.queue[index.to_i] = nil }
          schema.queue.compact!
        end
    
        redirect uri(id)
      end
      
      def configure(id)
        schema = Tap::Schema.new(request['schema'])

        persistence.update(:schema, id) do |io| 
          io << schema.dump
        end
        
        redirect uri(id)
      end
      
      protected # Helper Methods
      
      def env
        server.env
      end
      
      def load_schema(id)
        if path = persistence.find(:schema, id)
          Tap::Schema.load_file(path)
        else
          Tap::Schema.new
        end
      end
      
      def update_schema(id)
        path = persistence.find(:schema, id) || persistence.create(:schema, id)
        schema = Tap::Schema.load_file(path)
        
        yield(schema)
        
        persistence.update(:schema, id) do |io| 
          io << schema.dump
        end
      end
      
      def persistence
        server.persistence
      end
    end
  end
end