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
        resolve(schema)
        
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
        
        persistence.create(:schema, new_id) do |io| 
          io << persistence.read(:schema, id)
        end
        
        redirect uri(new_id)
      end
      
      # Adds nodes or joins to the schema.  Parameters:
      #
      # nodes[]:: An array of nodes to add to the schema. Each entry is split using
      #           Shellwords to yield an argv; the argv initializes the node.  The
      #           index of each new node is added to targets[].
      # sources[]:: An array of source node indicies used to create a join.
      # targets[]:: An array of target node indicies used to create a join (note
      #             the indicies of new nodes are added to targets).
      #
      # Add creates and pushes new nodes onto schema as specified in nodes, then
      # creates joins between the sources and targets.  The join class is inferred
      # by Utils.infer_join; if no join can be inferred the join class is 
      # effectively nil, and consistent with that, the node output for sources
      # and the node input for targets is set to nil.
      #
      # === Notes
      #
      # The nomenclature for source and target is relative to the join, and may
      # seem backwards for the node (ex: 'sources[]=0&targets[]=1' makes a join
      # like '0:1')
      #
      def add(id)
        outputs = (request['outputs'] || []).collect {|index| index.to_i }
        inputs = (request['inputs'] || []).collect {|index| index.to_i }
        
        update_schema(id) do |schema|
          schema.joins << [inputs, outputs]
          schema.cleanup!
        end
        
        redirect(id)
      end
      
      # Removes nodes or joins from the schema.  Parameters:
      #
      # sources[]:: An array of source node indicies to remove.
      # targets[]:: An array of target node indicies to remove.
      #
      # Normally remove sets the node.output for each source to nil and the
      # node.input for each target to nil.  However, if a node is indicated in
      # both sources and targets AND it has no join input/output, then it will
      # be removed.
      #
      # === Notes
      #
      # The nomenclature for source and target is relative to the join, and may
      # seem backwards for the node (ex: for the sequence '0:1:2', 'targets[]=1'
      # breaks the join '0:1' while 'sources[]=1' breaks the join '1:2'.
      #
      def remove(id)
        round = (request['round'] || 0).to_i
        outputs = (request['outputs[]'] || []).collect {|index| index.to_i }
        inputs = (request['inputs[]'] || []).collect {|index| index.to_i }
    
        load_schema(id) do |schema|
          # Remove joins.  Removed indicies are popped to ensure
          # that if a join was removed the node will not be.
          outputs.delete_if do |index|
            next unless node = schema.nodes[index]
            if node.input_join
              node.input = round
              true
            else
              false
            end
          end
      
          inputs.delete_if do |index|
            next unless node = schema.nodes[index]
            if node.output_join
              node.output = nil
              true
            else
              false
            end
          end
    
          # Remove nodes. Setting a node to nil causes it's removal during 
          # compact; orphaned joins are removed during compact as well.
          (inputs & outputs).each do |index|
            schema.nodes[index] = nil
          end
        end
    
        redirect("/schema/display/#{id}")
      end
      
      ############################################################
      # Helper Methods
      ############################################################
      protected
      
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
        path = persistence.find(:schema, id)
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