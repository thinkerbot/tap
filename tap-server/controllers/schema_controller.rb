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
  end
  
  include Utils
  
  set :default_layout, 'layouts/default.erb'
  
  def index
    id = initialize_schema
    redirect("/schema/display/#{id}")
  end
  
  def display(id)
    schema = load_schema(id)
    render 'index.erb', :locals => {
      :id => id, 
      :schema => schema
    }, :layout => true
  end
  
  def update(id)
    case request['action']
    when 'add'
      load_schema(id) do |schema|
        schema.nodes << Tap::Support::Node.new(argv)
      end
    when 'remove'
      load_schema(id) do |schema|
        schema.nodes.delete_at(index.to_i)
      end
    else
      raise ServerError, "unknown action: #{request['action']}"
    end
    
    if request.get?
      redirect("/schema/display/#{id}")
    end
  end
  
  def submit(id)
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