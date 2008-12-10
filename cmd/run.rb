# tap run {options} -- {task options} task INPUTS...
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#

env = Tap::Env.instance
app = Tap::App.instance

#
# handle options
#

dump = false
ConfigParser.new do |opts|
  opts.separator ""
  opts.separator "configurations:"
  
  keys = Tap::App.configurations.keys - Tap::Root.configurations.keys
  keys.sort_by do |key|
    Tap::App.configurations[key].attributes[:declaration_order] || 0
  end.each do |key|
    config = Tap::App.configurations[key]
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
  
  opts.on('-T', '--manifest', 'Print a list of available tasks') do |v|
    puts env.summarize(:tasks)
    exit
  end
  
end.parse!(ARGV)

#
# build and run the argv
#

queues = env.build(ARGV)
ARGV.clear

if queues.empty?
  puts "no task specified"
  exit
end

env.set_signals
env.run(queues)

