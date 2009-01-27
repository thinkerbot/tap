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
  
  def index
    # parse a schema and clean it up using compact
    render 'run.erb', :locals => {:schema => schema}
  end
  
  def add
    index, sources, targets = parameters
    
    lines = []
    (req.params['tasc'] || []).select do |name|
      name && !name.empty?
    end.each do |name|
      index += 1
      targets << index
      lines << render('run/node.erb', :locals => {:node => Tap::Support::Node.new([name]), :index => index} )
    end
    
    n_sources = sources.length
    n_targets = targets.length
    join = case
    when n_sources == 1 && n_targets > 0
      Tap::Support::Schema::Utils.format_fork(sources, targets, {})
    when n_sources > 1 && n_targets == 1
      # need to determine if sources and
      # targets are already joined
      Tap::Support::Schema::Utils.format_merge(sources, targets, {})
    when n_sources == 0 && n_targets == 0
      nil # no join specified
    else
      nil # TODO: warn an multi-join was specified
    end
    
    lines << render('run/join.erb', :locals => {:join => join}) if join
    lines.join("\n")
  end
  
  def remove
    index, sources, targets = parameters
    
    # select joins for sources and targets
    
    # remove src/target if it belongs to no join
    # remove src/target from each join, as specified
    # remove join if empty
  end
  
  def run
    return preview if req.params['preview']
    
    # queues = env.build(schema, app)
    # # thread new...
    # env.run(queues)
    redirect('/app/run')
  end
  
  def preview
    res["Content-Type"] = 'text/plain'
    render('preview.erb', :locals => {:schema => schema})
  end
  
  def load
    argv = YAML.load(req.params['yaml'])

    # parse a schema and clean it up using compact
    schema = Tap::Support::Schema.parse(argv.flatten).compact
    render('run.erb', :locals => {:schema => schema})
  end
  
  protected
  
  def app
    Tap::App.instance
  end
  
  def schema
    parse_schema(req.params).compact
  end
  
  def parameters
    index = req.params['index'].to_i - 1
    sources = (req.params['sources'] || []).collect {|source| source.to_i }
    targets = (req.params['targets'] || []).collect {|target| target.to_i }
    
    [index, sources, targets]
  end
end