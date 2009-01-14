# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require 'tap/server/utils'

env = Tap::Env.instance

# initialize with HTML generation methods
cgi = CGI.new("html3")  
cgi.out() do
  case cgi.request_method
  when /GET/i
    # parse a schema and clean it up using compact
    schema = Tap::Server::Utils.parse_schema(cgi.params).compact
    env.render('run.erb', :env => env, :schema => schema)
  
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
        lines << env.render('run/node.erb', :env => env, :node => Tap::Support::Node.new([name]), :index => index )
      end
      
      join = case
      when sources.length > 1 && targets.length == 1
        Tap::Support::Schema::Utils.format_merge(sources, targets, {})
      when sources.length == 1 && targets.length > 0
        Tap::Support::Schema::Utils.format_fork(sources, targets, {})
      else nil
      end
      
      lines << env.render('run/join.erb', :env => env, :join => join) if join
      lines.join("\n")
    
    when 'remove'

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
