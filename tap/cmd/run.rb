# usage: tap run FILEPATHS... [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#

env = Tap::Env.instance
app = Tap::App.instance

#
# divide argv
#

run_argv = []
break_regexp = Tap::Support::Parser::BREAK
while !ARGV.empty? && ARGV[0] !~ break_regexp
  run_argv << ARGV.shift
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
  
end.parse!(run_argv, app.config)

#
# build and run the argv
#

run_argv.each do |path|
  unless File.exists?(path)
    puts "No such file or directory - #{path}"
    puts "(did you mean 'tap run -- #{path}'?)"
    exit
  end
  
  schema = Tap::Support::Schema.load_file(path)
  env.build(schema, app)
end

schema = Tap::Support::Schema.parse(ARGV)
ARGV.clear
env.build(schema, app)

if app.queue.empty?
  puts "no task specified"
  exit
end

env.set_signals
app.run
