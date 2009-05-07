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
schemas = []
ConfigParser.new(app.config) do |opts|
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
    tasks = env.tasks
    tasks_found = !tasks.all_empty?
    
    middleware = env.middleware
    middleware_found = !middleware.all_empty?
    
    if tasks_found 
      puts "=== tasks ===" if middleware_found
      puts tasks.summarize
    end

    if middleware_found
      puts "=== middleware ===" if tasks_found
      puts middleware.summarize
    end
    
    exit(0)
  end
  
  opts.on('-m', '--middleware MIDDLEWARE', 'Specify app middleware') do |key|
    middleware = env.middleware[key] or raise("unknown middleware: #{key}")
    app.use(middleware)
  end
  
  opts.on("-s", "--schema FILE", "Build the schema file") do |path|
    unless File.exists?(path)
      puts "No such schema file - #{path}"
      exit(1)
    end
    
    schemas << Tap::Schema.load_file(path)
  end
  
end.parse!(argv, :clear_config => false, :add_defaults => false)

#
# build and run
#

begin
  # parse argv schema
  schemas << Tap::Schema.parse(ARGV)
  ARGV.replace(argv)
  
  env.run(schemas, app)
rescue
  raise if $DEBUG
  puts $!.message
  if $!.message == "no nodes specified" && !ARGV.empty?
    puts "(did you mean 'tap run -- #{ARGV.join(' ')}'?)"
  end
  exit(1)
end

exit(0)