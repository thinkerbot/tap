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
    exit(0)
  end
  
  opts.on('-T', '--manifest', 'Print a list of available tasks') do
    puts env.tasks.summarize
    exit(0)
  end
  
  opts.on("-s", "--schema FILE", "Build the schema file") do |path|
    unless File.exists?(path)
      puts "No such schema file - #{path}"
      exit(1)
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

begin
  manifests = env.manifests
  schemas.each do |schema|
    env.build(schema, app, manifests).each do |queue|
      app.queue.concat(queue)
    end
  end
rescue
  raise if $DEBUG
  puts $!.message
  exit(1)
end

if app.queue.empty?
  puts "no task specified"
  unless ARGV.empty?
    puts "(did you mean 'tap run -- #{ARGV.join(' ')}'?)"
  end
  exit(1)
end

env.set_signals(app)
app.run
