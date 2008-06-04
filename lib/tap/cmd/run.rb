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
  
  opts.on('-T', '--task-manifest', 'Print a list of available tasks') do |v|
    manifest = app.manifest.auto_discover(app, env.load_paths).to_hash

    widths = []
    manifest_by_load_path = {}
    manifest.each_pair do |name, spec| 
      (manifest_by_load_path[spec.load_path] ||= {})[name] = spec
      widths << name.length
    end
    width = widths.max || 10
    
    max_column = 80 - width - 7
    manifest_by_load_path.each_pair do |path, specs|
      puts "===  tap tasks (#{path})"
      specs.each_pair do |name, spec|
        printf "%-#{width}s  # %s\n", name, spec.tdoc.summary#rake.truncate(spec.tdoc.comment, max_column)
      end
    end
    
    puts "=== rake tasks"
    env.rake_setup(['-T']).display_tasks_and_comments
    
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
        case arg 
        when "--help"
          env.log(:warn, "ignoring --help option for rake command")
        else
          next(false)
        end
        
        true
      end
 
      rake_app = env.rake_setup if rake_app == nil
      rake_app.top_level_tasks.each do |task_name|
        app.enq(rake_app[task_name])
      end
      
    else  
      begin
        # attempt lookup the task class
        task_class = td.camelize.constantize
      rescue(NameError)
        env.log(:warn, "NameError: #{$!.message}", Logger::DEBUG)
      end

      # unless a Tap::Task was found, treat the
      # args as a specification for Rake.
      if task_class == nil || !task_class.include?(Tap::Support::Framework)
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

