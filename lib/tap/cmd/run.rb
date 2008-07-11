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
rake = true
rake_app = nil
print_manifest = false
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::TDoc.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on('-T', '--task-manifest', 'Print a list of available tasks') do |v|
    print_manifest = true
  end
  
  opts.on('-d', '--debug', 'Trace execution and debug') do |v|
    app.options.debug = v
  end

  opts.on('--force', 'Force execution at checkpoints') do |v|
    app.options.force = v
  end
  
  opts.on('--dump', 'Specifies a default dump task') do |v|
    dump = v
  end
  
  opts.on('--[no-]rake', 'Enables or disables rake task handling') do |v|
    rake = v
  end
  
  opts.on('--quiet', 'Suppress logging') do |v|
    app.options.quiet = v
  end
  
end.parse!(ARGV)

if print_manifest
  tasks_by_load_path = {}
  width = 10
  env.each do |e|
    e.tasks.each_pair do |load_path, documents|
      documents.each do |document|
        document.attributes.each_pair do |namespace, hash|
          name = namespace.underscore
          width = name.length if width < name.length
          (tasks_by_load_path[load_path] ||= []) << [name, hash[:summary]]
        end
      end
    end
  end

  max_column = 80 - width - 7
  tasks_by_load_path.each_pair do |path, tasks|
    puts "===  tap tasks (#{path})"
    tasks.each do |task|
      print("%-#{width}s  # %s\n" % task)#rake.truncate(spec.tdoc.comment, max_column)
    end
  end
  
  if rake 
    puts "=== rake tasks"
    ARGV.clear
    env.rake_setup(['-T']).display_tasks_and_comments
  end
  
  exit
end

#
# handle options for each specified task
#
rounds = Tap::Support::CommandLine.split_argv(ARGV).collect do |argv|
  argv.each do |args|
    ARGV.clear  
    ARGV.concat(args)
   
    td = Tap::Support::CommandLine.next_arg(ARGV)
    case
    when rake && td == 'rake'
      rake_app = env.rake_setup if rake_app == nil
      begin
        rake_app.enq_top_level(app)
      rescue(RuntimeError)
        if $!.message =~ /^Don't know how to build task '(.*)'$/
          raise "unknown task: #{$1}"
        else
          raise $!
        end
      end
    
    when td == nil
      # warn?
      next 
    else  

      # attempt lookup the task class
      task_class = env.constantize(td) 

      # unless a Tap::Task was found, treat the
      # args as a specification for Rake.
      if task_class == nil || !task_class.include?(Tap::Support::Framework)
        raise "unknown task: #{td}" if !rake || ARGV.include?('--help')
        
        env.log(:warn, "implicit rake: #{td}#{ARGV.empty? ? '' : ' ...'}", Logger::DEBUG)
        args.unshift('rake')
        redo
      end
    
      # now let the class handle the argv
      name, config, argv = task_class.parse_argv(ARGV, true)
      name = td if name == nil
      
      argv.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
      task_class.enq(name, config, app, argv)
    end
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

