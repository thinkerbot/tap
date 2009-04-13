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

env = Tap::Exe.instance
app = env.app

#
# divide argv
#

argv = []
break_regexp = Tap::Schema::Parser::BREAK
while !ARGV.empty? && ARGV[0] !~ break_regexp
  argv << ARGV.shift
end

#
# handle options
#

dump = false
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
    puts env.summarize(:tasks)
    exit
  end
  
  opts.on("-w", "--workflow FILE", "Build the workflow file") do |path|
    unless File.exists?(path)
      puts "No such file or directory - #{path}"
      puts "(did you mean 'tap run -- #{path}'?)"
      exit
    end

    schema = Tap::Support::Schema.load_file(path)
    env.build(schema, app)
  end
  
end.parse!(argv, app.config)

#
# build and run the argv
#

schema = Tap::Support::Schema.parse(ARGV)
env.build(schema, app)
ARGV.replace(argv)

if app.queue.empty?
  puts "no task specified"
  unless ARGV.empty?
    puts "(did you mean 'tap run -- #{ARGV.join(' ')}'?)"
  end
  exit
end

env.set_signals
app.run
