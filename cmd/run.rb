# tap run {options} -- {task options} task INPUTS...
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#

env = Tap::Env.instance.envs[0]
app = Tap::App.instance
cmdline = Tap::Support::CommandLine

#
# handle options
#

dump = false
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::CommandLine.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on('-T', '--manifest', 'Print a list of available tasks') do |v|
    puts env.summarize(:tasks) {|const| const.document[const.name]['manifest'] }
    exit
  end
  
  opts.on('--dump', 'Specifies a default dump task') do |v|
    dump = v
  end
  
end.parse!(ARGV)

#
# handle options for each specified task
#

rounds = cmdline.split(ARGV).collect do |argv|
  argv.each do |args|
    ARGV.clear  
    ARGV.concat(args)
   
    unless td = cmdline.shift(ARGV)
      # warn nil?
      next
    end

    # attempt lookup the task class
    const = env.search(:tasks, td) or raise "unknown task: #{td}"
    task_class = const.constantize or raise "unknown task: #{td}"
    
    # now let the class handle the argv
    task, argv = task_class.argv_new(ARGV, app)
    task.enq *argv.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
  end

  app.queue.clear
end
ARGV.clear

rounds.delete_if {|round| round.empty? }
if rounds.empty?
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
  
  # puts "ctl-i prints information"
end

# interuption signal
if signals.include?("INT")
  Signal.trap("INT") do
    puts " interrupted!"
    # prompt for decision
    while true
      print "stop, terminate, or resume? (s/t/r):"
      case gets.strip
      when /s(top)?/i 
        app.stop
        break
      when /t(erminate)?/i 
        app.terminate
        break
      when /r(esume)?/i 
        break
      else
        puts "unexpected response..."
      end
    end
  end

  # puts "ctl-c interupts execution"
end

#
# enque tasks and run!
#
# puts "beginning run..."
rounds.each_with_index do |queue, i|
  app.queue.concat(queue)
  app.run
end

if dump
  puts
  Tap::Dump.new.enq
  app.run
end

