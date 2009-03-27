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
          :schema => persistence.index
        }, :layout => true
      end
      
      # GET /projects/id
      def show(id=persistence.next_id)
        extname = File.extname(id)
        id = id.chomp(extname)
        schema = load_schema(id)
        
        case extname
        when '.txt'
          response.headers['Content-Type'] = 'text/plain'
          YAML.dump(schema.dump)
        when '.yml'
          response.headers['Content-Type'] = 'text/plain'
          response['Content-Disposition'] = "attachment; filename=#{id}.yml;"
          YAML.dump(schema.dump)
        else
          render 'schema.erb', :locals => {
            :id => id,
            :schema =>schema
          }, :layout => true
        end
      end
      
      # 
      #     # GET /projects/arg;edit/*args
      #     def edit(arg, *args)...
      
      # Updates the specified schema with the request parameters.  Update forwards
      # the request to the action ('add' or 'remove') specified in the action
      # parameter.
      # POST /projects/*args
      def create(*id)
        case request['action']
        # rest actions
        when 'update' then update(id)
        when 'destroy' then destroy(id)
        
        # create actions
        when 'add'    then add(id)
        when 'remove' then remove(id)
        when 'echo'   then echo
        else raise Tap::ServerError, "unknown action: #{request['action']}"
        end
      end
      
      # PUT /projects/*args
      def update(id)
        save_schema(id, request_schema)
        redirect("/schema/#{id}")
      end
      
      # DELETE /projects/*args
      def destroy(id)
        persistence.destroy(id)
        redirect("/schema")
      end
        
      ############################################################
      # Helper Methods
      ############################################################
      protected
      
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
        round = (request['round'] || 0).to_i
        outputs = (request['outputs[]'] || []).collect {|index| index.to_i }
        inputs = (request['inputs[]'] || []).collect {|index| index.to_i }
        nodes = request['nodes[]'] || []
          
        load_schema(id) do |schema|
          nodes.each do |arg|
            next unless arg && !arg.empty?
      
            outputs << schema.nodes.length
            schema.nodes << Tap::Support::Node.new(Shellwords.shellwords(arg), round)
          end
      
          if inputs.empty? || outputs.empty?
            inputs.each {|index| schema[index].output = nil }
            outputs.each {|index| schema[index].input = round }
          else
            schema.set(Tap::Support::Join, inputs, outputs)
          end
        end
        
        redirect("/schema/#{id}")
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
          
        redirect("/schema/#{id}")
      end
      
      # helper to echo requests back... used to debug http requests
      def echo
        "<pre>#{request.params.to_yaml}</pre>"
      end
      
      # Parses a Tap::Support::Schema from the request.
      def request_schema
        argv = request['argv[]'] || []
        argv.delete_if {|arg| arg.empty? }
        Tap::Support::Schema.parse(argv)
      end
      
      def load_schema(id)
        schema = if persistence.has?(id)
          Tap::Support::Schema.load_file(persistence.path(id))
        else
          Tap::Support::Schema.new
        end
        
        if block_given?
          result = yield(schema)
          save_schema(id, schema)
          result
        else
          schema
        end
      end
        
      def save_schema(id, schema=nil)
        persistence.update(id) do |file|
          file << YAML.dump(schema.dump) if schema
        end
      end
        
      def instantiate(*argv)
        key = argv.shift
        tasc = server.env.tasks.search(key).constantize 
        tasc.parse(argv)
      end        
    end
  end
end