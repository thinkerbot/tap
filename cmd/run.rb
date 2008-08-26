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
    
    opts.on(*cmdline.configv(config)) do |value|
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
# handle options for each specified task
#

queues = env.parse(ARGV)
ARGV.clear

if queues.empty?
  puts "no task specified"
  exit
end

#
# set signals 
#

# info signal -- Note: some systems do 
# not support the INFO signal 
# (windows, fedora, at least)
signals = Signal.list.keys
if signals.include?("INFO")
  Signal.trap("INFO") do
    puts app.info
  end
end

# interuption signal
if signals.include?("INT")
  Signal.trap("INT") do
    puts " interrupted!"
    # prompt for decision
    while true
      print "stop, terminate, exit, or resume? (s/t/e/r):"
      case gets.strip
      when /s(top)?/i 
        app.stop
        break
      when /t(erminate)?/i 
        app.terminate
        break
      when /e(xit)?/i 
        exit
      when /r(esume)?/i 
        break
      else
        puts "unexpected response..."
      end
    end
  end
end

#
# enque tasks and run!
#

queues.each_with_index do |queue, i|
  app.queue.concat(queue)
  app.run
end
