require 'tap/controller'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"

class SchemaController < Tap::Controller
  module Utils
    module_function

    def parse_schema(params)
      argh = pair_parse(params)

      parser = Tap::Support::Parser.new
      parser.parse(argh['nodes'] || [])
      parser.parse(argh['joins'] || [])
      parser.schema
    end

    # UrlEncodedPairParser.parse, but also doing the following:
    #
    # * reads io values (ie multipart-form data)
    # * keys ending in %w indicate a shellwords argument; values
    #   are parsed using shellwords and concatenated to other
    #   arguments for key
    #
    # Returns an argh.  The schema-related entries will be 'nodes' and
    # 'joins', but other entries may be present (such as 'action') that
    # dictate what gets done with the params.
    def pair_parse(params)
      params.keys.each do |key|
        next unless key && key =~ /%w$/
        value = params.delete(key)
        key = key.chomp("%w")
      
        (params[key] ||= []).concat Shellwords.shellwords(value)
      end

      UrlEncodedPairParser.new(params).result   
    end
    
    def infer_join(sources, targets)
      case sources.length
      when 0 then nil
      when 1
        # one source: join
        case targets.length
        when 0 then return nil
        when 1 then Tap::Support::Joins::Sequence
        else Tap::Support::Joins::Fork
        end
      else
        # many sources: reverse_join
        case targets.length
        when 0 then return nil
        when 1 then Tap::Support::Joins::Merge
        else raise Tap::ServerError, "multi-join specified: #{sources.inspect} => #{targets.inspect}"
        end
      end
    end
  end
  
  include Utils
  
  set :default_layout, 'layouts/default.erb'
  
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
    when 'add' then add(id)
    when 'remove' then remove(id)
    else raise Tap::ServerError, "unknown action: #{request['action']}"
    end
  end
  
  # Adds nodes or joins to the schema.  Parameters:
  #
  # nodes[]:: An array of nodes to add to the schema. Each entry is split using
  #           Shellwords to yield an argv; the argv initializes the node.  The
  #           index of each new node is added to targets[].
  # sources[]:: An array of source indicies used to create a join.
  # targets[]:: An array of target indicies used to create a join (note the
  #             indicies of new nodes are added to targets).
  #
  def add(id)
    unless request.post?
      raise Tap::ServerError, "update must be performed with post"
    end
    
    targets = (request['targets[]'] || []).collect {|index| index.to_i }
    sources = (request['sources[]'] || []).collect {|index| index.to_i }
    nodes = request['nodes[]'] || []
    
    load_schema(id) do |schema|
      nodes.each do |arg|
        next unless arg && !arg.empty?

        targets << schema.nodes.length
        schema.nodes << Tap::Support::Node.new( Shellwords.shellwords(arg) )
      end
      
      if join = infer_join(sources, targets)
        schema.set(join, sources, targets)
      else
        sources.each {|index| schema[index].output = nil }
        targets.each {|index| schema[index].input = nil }
      end
      
      schema.compact
    end
    
    redirect("/schema/display/#{id}")
  end
  
  def submit(id)
    unless request.post?
      raise Tap::ServerError, "submit must be performed with post"
    end
    
    case request['action']
    when 'update'
      dump_schema(id, schema)
      redirect("/schema/display/#{id}")
    when 'preview'
      response.headers['Content-Type'] = 'text/plain'
      render('preview.erb', :locals => {:id => id, :schema => schema})
    when 'run'
      
    else
      raise ServerError, "unknown action: #{request['action']}"
    end
  end
  
  protected
  
  # Parses a compacted Tap::Support::Schema from the request.
  def schema
    parse_schema(request.params).compact
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
  
  def remove(schema)
    targets = (request['targets[]'] || []).collect {|index| index.to_i }
    sources = (request['sources[]'] || []).collect {|index| index.to_i }
    
    # setting a node to nil causes it's removal during compact;
    # orphaned joins are removed during compact as well.
    (sources + targets).each do |index|
      schema.nodes[index] = nil
    end
    
    schema.compact
  end
  
  def instantiate(*argv)
    key = argv.shift
    tasc = server.env.tasks.search(key).constantize 
    tasc.parse(argv)
  end
  
  # Generates a random integer key.
  def random_key(length) # :nodoc:
    length = 1 if length < 1
    rand(length * 10000).to_s
  end
end