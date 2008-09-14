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
OptionParser.new do |opts|
  cmdline = Tap::Support::CommandLine
  
  opts.separator ""
  opts.separator "configurations:"
  
  Tap::App.configurations.each do |receiver, key, config|
    next if receiver == Tap::Root
    
    opts.on(*config.to_optparse_argv) do |value|
      app.send(config.writer, value)
    end
  end
 
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = cmdline.usage(__FILE__)
    Tap::App.lazydoc.resolve
    puts opts
    exit
  end
  
  opts.on('-T', '--manifest', 'Print a list of available tasks') do |v|
    puts env.summarize(:tasks) {|const| const.document[const.name]['manifest'] }
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

