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
      pairs = {}
      params.each_pair do |key, values|
        next if key == nil
        key = key.chomp("%w") if key =~ /%w$/

        resolved_values = pairs[key] ||= []
        values.each do |value|
          value = value.respond_to?(:read) ? value.read : value

          # $~ indicates if key matches shellwords pattern
          if $~ 
            resolved_values.concat(Shellwords.shellwords(value))
          else 
            resolved_values << value
          end
        end
      end

      UrlEncodedPairParser.new(pairs).result   
    end
  end
  
  include Utils
  
  set :default_layout, 'layouts/default.erb'
  
  def index
    id = initialize_schema
    redirect("/schema/display/#{id}")
  end
  
  def display(id)
    render 'index.erb', :locals => {:id => id, :schema => load_schema(id)}, :layout => true
  end
  
  def add(id, *argv)
    # TODO: parse configs/args from config
    
    load_schema(id) do |schema|
      schema.nodes << Tap::Support::Node.new(argv)
    end
    
    if request.get?
      redirect("/schema/display/#{id}")
    end
  end
  
  def remove(id, index)
    load_schema(id) do |schema|
      schema.nodes.delete_at(index.to_i)
    end
    
    if request.get?
      redirect("/schema/display/#{id}")
    end
  end
  
  def run(id)
    case request['action']
    when 'update'
      dump_schema(id, schema)
      redirect("/schema/display/#{id}")
    when 'preview'
      response.content_type = 'text/plain'
      render('preview.erb', :locals => {:id => id, :schema => schema})
    when 'run'
    else
      
    end
  end
  
  def load
    argv = YAML.load(req.params['yaml'])

    # parse a schema and clean it up using compact
    schema = Tap::Support::Schema.parse(argv.flatten).compact
    render('run.erb', :locals => {:schema => schema})
  end
  
  protected
  
  def initialize_schema
    current = app.glob(:schema, "*").collect {|path| File.basename(path).chomp(".yml") }
    
    id = random_key(current.length)
    while current.include?(id)
      id = random_key(current.length)
    end
    
    dump_schema(id)
    id
  end
  
  def dump_schema(id, schema=nil)
    app.prepare(:schema, "#{id}.yml") do |file|
      file << schema.dump.to_yaml if schema
    end
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
  
  # Parses a compacted Tap::Support::Schema from the request.
  def schema
    parse_schema(request.params).compact
  end
  
  # Parses a hash of schema parameters specified by the request.  The fields
  # in parameters correspond to those produced by the Tap.Schema.parameters
  # function in public/tap.js.
  def parameters
    {
      :index => (request['index'].to_i - 1),
      :sources => (request['sources'] || []).collect {|source| source.to_i },
      :targets => (request['targets'] || []).collect {|target| target.to_i },
      :tascs => (request['tascs'] || [])
    }
  end
  
  # Generates a random integer key.
  def random_key(length) # :nodoc:
    length = 1 if length < 1
    rand(length * 10000).to_s
  end
end