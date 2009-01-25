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
    env.render :views, 'run.erb', :schema => schema.compact
  end
  
  def add
    index, sources, targets = parameters
    
    lines = []
    (req.params['tasc'] || []).select do |name|
      name && !name.empty?
    end.each do |name|
      index += 1
      targets << index
      lines << env.render(:views, 'run/node.erb', :node => Tap::Support::Node.new([name]), :index => index )
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
    
    lines << env.render(:views, 'run/join.erb', :join => join) if join
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
    log_file = env.root.prepare(:log, 'server.log')
    env.app.logger = Logger.new(log_file)
    
    queues = env.build(schema)
    # thread new...
    env.run(queues)
    env.render(:views, 'tail.erb', :path => log_file, :pos => 0, :update => true)
  end
  
  protected
  
  def schema
    parse_schema(req.params)
  end
  
  def parameters
    index = req.params['index'].to_i - 1
    sources = (req.params['sources'] || []).collect {|source| source.to_i }
    targets = (req.params['targets'] || []).collect {|target| target.to_i }
    
    [index, sources, targets]
  end
end