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
rake = false
rake_app = nil
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::TDoc.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on('-T', '--task-manifest', 'Print a list of available tasks.') do |v|
    manifest = Tap::Support::TDoc.manifest(*env.load_paths)
    
    rake = env.rake_setup(['-T'])
    displayable_tasks = rake.tasks.select { |t|
      t.comment && t.name =~ rake.options.show_task_pattern
    }
    
    widths = []
    manifest.each {|path, hash| hash.keys.each {|key| widths << key.length }}
    displayable_tasks.collect {|t| widths << 5 + t.name_with_args.length}
    width = widths.max || 10
    
    max_column = 80 - width - 7
   
    manifest.each do |path, hash|
      next if hash.empty?
      puts "===  tap tasks (#{path})"
      hash.each_pair do |name, comment|
        printf "%-#{width}s  # %s\n", name, rake.truncate(comment, max_column)
      end
    end
    
    puts "=== rake tasks"
    displayable_tasks.each do |t|
      printf "%-#{width}s  # %s\n", "rake " + t.name_with_args, rake.truncate(t.comment, max_column)
    end
    exit
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

#
# handle options for each specified task
#
rounds = Tap::Support::CommandLine.split_argv(ARGV).collect do |argv|
  argv.each do |args|
    ARGV.clear  
    ARGV.concat(args)
   
    td = Tap::Support::CommandLine.next_arg(ARGV)
    case td
    when 'rake', nil  
      # remove --help as this will print the Rake help
      ARGV.delete_if do |arg|
        if arg == "--help"
          env.log(:warn, "ignoring --help option for rake command") 
          true
        else
          false
        end
      end
 
      rake_app = env.rake_setup if rake_app == nil
      rake_app.argv_enq(app)
  
    else  
      begin
        # attempt lookup the task class
        task_class = app.task_class(td)
      rescue(Tap::App::LookupError)
      end

      # unless a Tap::Task was found, treat the
      # args as a specification for Rake.
      if task_class == nil || !task_class.kind_of?(Tap::Support::FrameworkMethods)
        raise "unknown task: #{td}" unless rake
        
        env.log(:warn, "implicit rake: #{td}#{ARGV.empty? ? '' : ' ...'}", Logger::DEBUG)
        args.unshift('rake')
        redo
      end
    
      # now let the class handle the argv
      name, config, argv = task_class.parse_argv(ARGV, true)
      name = td if name == nil
      
      task = task_class.new(name, config, app)
      task.enq *argv.collect {|str| Tap::Support::CommandLine.parse_yaml(str) }
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
  app.task('tap/dump').enq
  app.run
end

