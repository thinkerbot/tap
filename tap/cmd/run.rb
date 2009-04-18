# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -w workflow.yml            Build and run a workflow
#   tap run -w workflow.yml a b c      Same with [a, b, c] ARGV
#
# schema:
#   tap run -- task --help             Prints help for task
#   tap run -- load hello --: dump     Say hello
#

env = Tap::Env.instance
app = Tap::App.new

#
# parse argv
#

# separate out argv schema
argv = []
break_regexp = Tap::Schema::Parser::BREAK
while !ARGV.empty? && ARGV[0] !~ break_regexp
  argv << ARGV.shift
end

# parse options
dump = false
schemas = []
ConfigParser.new do |opts|
  opts.separator ""
  opts.separator "configurations:"
  
  root_keys = Tap::Root.configurations.keys
  Tap::App.configurations.each_pair do |key, config|
    next if root_keys.include?(key)
    opts.define(key, config.default, config.attributes)
  end
 
  opts.separator ""
  opts.separator "options:"
  
  opts.on("-h", "--help", "Show this message") do
    Tap::App.lazydoc.resolve
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on('-T', '--manifest', 'Print a list of available tasks') do
    puts env.tasks.summarize(%Q{<% unless entries.empty? %>
<%= env_key %>:
<% entries.each do |key, const| %>
  <%= key.ljust(width-2) %> # <%= const.comment %>
<% end %>
<% end %>
})
    exit
  end
  
  opts.on("-w", "--workflow FILE", "Build the workflow file") do |path|
    unless File.exists?(path)
      puts "No such file or directory - #{path}"
      puts "(did you mean 'tap run -- #{path}'?)"
      exit
    end
    
    schemas << Tap::Schema.load_file(path)
  end
  
end.parse!(argv, app.config)

# parse argv schema
schemas << Tap::Schema.parse(ARGV)
ARGV.replace(argv)

#
# build and run
#

manifests = env.manifests
schemas.each do |schema|
  env.build(schema, manifests).each do |queue|
    app.queue.concat(queue)
  end
end

if app.queue.empty?
  puts "no task specified"
  unless ARGV.empty?
    puts "(did you mean 'tap run -- #{ARGV.join(' ')}'?)"
  end
  exit
end

env.set_signals(app)
app.run
