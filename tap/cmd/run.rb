# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -s schema.yml              Build and run a workflow
#   tap run -s schema.yml a b c        Same with [a, b, c] ARGV
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
    tasks = env.manifest(:task)
    tasks_found = !tasks.all_empty?
    
    middleware = env.manifest(:middleware)
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
  
end.parse!(argv, :clear_config => false, :add_defaults => false)

#
# build and run
#

begin
  if ARGV.empty?
    msg = "No schema specified"
    
    unless argv.empty?
      args = argv[0, 3].join(' ') + (argv.length > 3 ? ' ...' : '')
      msg = "#{msg} (did you mean 'tap run -- #{args}'?)"
    end
    
    puts msg
    exit(0)
  end
  
  # parse argv schema
  schema = Tap::Schema.parse(ARGV)
  app.build(schema, :resources => env)
  
  ARGV.replace(argv)
  Tap::Exe.set_signals(app)
  
  app.run
rescue
  raise if $DEBUG
  puts $!.message
  exit(1)
end

exit(0)