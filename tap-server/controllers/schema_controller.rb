require 'tap/controller'

class SchemaController < Tap::Controller
  set :default_layout, 'layout.erb'
  
  # Initializes a new schema and redirects to display.
  def index
    id = initialize_schema
    redirect("/schema/display/#{id}")
  end
  
  # Loads the schema indicated by id and renders 'schema.erb' with the default
  # layout.
  def display(id)
    schema = load_schema(id)
    render 'schema.erb', :locals => {
      :id => id, 
      :schema => schema
    }, :layout => true
  end
  
  # Updates the specified schema with the request parameters.  Update forwards
  # the request to the action ('add' or 'remove') specified in the action
  # parameter.
  def update(id)
    case request['action']
    when 'add'    then add(id)
    when 'remove' then remove(id)
    when 'echo'   then echo
    else raise Tap::ServerError, "unknown action: #{request['action']}"
    end
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
    unless request.post?
      raise Tap::ServerError, "add must be performed with post"
    end
    
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
        
        # temporary
        if inputs.length > 1 && outputs.length > 1
          raise "multi-way join specified"
        end
        
        schema.set(Tap::Support::Join, inputs, outputs)
      end
    end
    
    redirect("/schema/display/#{id}")
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
    unless request.post?
      raise Tap::ServerError, "remove must be performed with post"
    end
    
    round = (request['round'] || 0).to_i
    outputs = (request['outputs[]'] || []).collect {|index| index.to_i }
    inputs = (request['inputs[]'] || []).collect {|index| index.to_i }
    
    load_schema(id) do |schema|
      # Remove joins.  Removed indicies are popped to ensure
      # that if a join was removed the node will not be.
      inputs.delete_if do |index|
        next unless node = schema.nodes[index]
        if node.output_join
          node.output = nil
          true
        else
          false
        end
      end
    
      outputs.delete_if do |index|
        next unless node = schema.nodes[index]
        if node.input_join
          node.input = round
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
  
  def submit(id)
    case request['action']
    when 'save'    then save(id)
    when 'preview' then preview(id)
    when 'echo'    then echo
    when 'run'
      dump_schema(id, schema)
      run(id)
    else raise Tap::ServerError, "unknown action: #{request['action']}"
    end
  end
  
  def save(id)
    unless request.post?
      raise Tap::ServerError, "submit must be performed with post"
    end
    
    dump_schema(id, schema)
    redirect("/schema/display/#{id}")
  end
  
  def preview(id)
    response.headers['Content-Type'] = 'text/plain'
    render('preview.erb', :locals => {:id => id, :schema => schema})
  end
  
  def run(id)
    unless request.post?
      raise Tap::ServerError, "run must be performed with post"
    end
    
    # it would be nice to someday put all this on a separate thread...
    schema = load_schema(id)
    tasks = server.env.tasks
    schema.build(app) do |(key, *args)|
      if const = tasks.search(key) 
        const.constantize.parse(args, app) do |help|
          raise "help not implemented"
          #redirect("/app/help/#{key}")
        end
      else
        raise ArgumentError, "unknown task: #{key}"
      end
    end
    
    Thread.new { app.run }
    redirect("/app/tail")
  end
  
  protected
  
  # Parses a Tap::Support::Schema from the request.
  def schema
    argv = request['argv[]'] || []
    argv.delete_if {|arg| arg.empty? }
    Tap::Support::Schema.parse(argv)
  end
  
  def initialize_schema
    current = app.glob(:schema, "*").collect {|path| File.basename(path).chomp(".yml") }
    
    id = random_key(current.length)
    while current.include?(id)
      id = random_key(current.length)
    end
    
    dump_schema(id, schema)
    id
  end
  
  def load_schema(id)
    unless path = app.filepath(:schema, "#{id}.yml")
      raise ServerError, "no schema for id: #{id}"
    end
    schema = Tap::Support::Schema.load_file(path)
    
    if block_given?
      result = yield(schema)
      dump_schema(id, schema)
      result
    else
      schema
    end
  end
  
  def dump_schema(id, schema=nil)
    app.prepare(:schema, "#{id}.yml") do |file|
      file << schema.dump.to_yaml if schema
    end
  end
  
  def instantiate(*argv)
    key = argv.shift
    tasc = server.env.tasks.search(key).constantize 
    tasc.parse(argv)
  end
  
  # helper to echo requests back... good for debugging
  def echo # :nodoc:
    "<pre>#{request.params.to_yaml}</pre>"
  end
  
  # Generates a random integer key.
  def random_key(length) # :nodoc:
    length = 1 if length < 1
    rand(length * 10000).to_s
  end
end