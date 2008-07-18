# tap run {options} -- {task options} task INPUTS...
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#

env = Tap::Env.instance.envs[0]
app = Tap::App.instance

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
    width = 10
    lines = []
    env.map(:tasks).each do |(env_lookup, env, map)|
      lines <<  "=== #{env_lookup} (#{env.root.root})" 
      map.each do |(key, path)|
        width = key.length if width < key.length
        document = Tap::Support::Lazydoc[path]
        lines <<  [key, document['']['manifest']]
      end
    end
  
    lines << "=== no tap tasks found" if lines.empty?
  
    lines.each do |line|
      puts(line.kind_of?(Array) ? ("%-#{width}s  # %s" % line) : line)
    end

    exit
  end
  
  opts.on('--dump', 'Specifies a default dump task') do |v|
    dump = v
  end
  
end.parse!(ARGV)

#
# handle options for each specified task
#

rounds = Tap::Support::CommandLine.split_argv(ARGV).collect do |argv|
  argv.each do |args|
    ARGV.clear  
    ARGV.concat(args)
   
    td = Tap::Support::CommandLine.next_arg(ARGV)
    
    # warn nil?
    next if td == nil

    # attempt lookup the task class
    name, path = env.search(:tasks, td)
    task_class = if name == nil 
      nil
    else
      require path
      name.camelize.try_constantize {|const_name| nil }
    end

    # unless a Tap::Task was found, treat the
    # args as a specification for Rake.
    if task_class == nil || !task_class.include?(Tap::Support::Framework)
      raise "unknown task: #{td}"
    end
    
    # now let the class handle the argv
    name, config, argv = task_class.parse_argv(ARGV)
    name = td if name == nil
    
    argv.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
    task_class.enq(name, config, app, argv)
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
  
  puts "ctl-i prints information"
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

  puts "ctl-c interupts execution"
end

#
# enque tasks and run!
#
puts "beginning run..."
rounds.each_with_index do |queue, i|
  app.queue.concat(queue)
  app.run
end

if dump
  puts
  Tap::Dump.new.enq
  app.run
end

