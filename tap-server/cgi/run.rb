# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'

env = Tap::Env.instance

# initialize with HTML generation methods
cgi = CGI.new("html3")  
cgi.out() do
  case cgi.request_method
  when /GET/i
    # parse a schema and clean it up using compact
    schema = Tap::Server::Utils.parse_schema(cgi.params).compact
    env.render('run.erb', :schema => schema)
  
  when /POST/i
    action = cgi.params['action'][0]
    case action
    when 'add'
      index = cgi.params['index'][0].to_i - 1
      sources = cgi.params['sources'].flatten.collect {|source| source.to_i }
      targets = cgi.params['targets'].flatten.collect {|target| target.to_i }
      
      lines = []
      cgi.params['tasc'].select do |name|
        name && !name.empty?
      end.each do |name|
        index += 1
        targets << index
        lines << env.render('run/node.erb', :node => Tap::Support::Node.new([name]), :index => index )
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
      
      lines << env.render('run/join.erb', :join => join) if join
      lines.join("\n")
    
    when 'remove'
      sources = cgi.params['sources'].flatten.collect {|source| source.to_i }
      targets = cgi.params['targets'].flatten.collect {|target| target.to_i }
      
      # select joins for sources and targets
      
      # remove src/target if it belongs to no join
      # remove src/target from each join, as specified
      # remove join if empty

    else
      # run
      cgi.pre do
        schema = Tap::Server::Utils.parse_schema(cgi.params)
        schema.compact.dump.to_yaml
        #env.build(schema)
      end
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end
