# = Usage
# tap run {options} -- {task options} task INPUTS...
#
# examples:
#   tap run --help                 Prints this help
#   tap run -- task --help         Prints help for task
#

env = Tap::Env.instance
app = Tap::App.instance

#
# handle options
#

opts = [
  ['--help', '-h', GetoptLong::NO_ARGUMENT, "Print this help"],
  ['--debug', '-d', GetoptLong::NO_ARGUMENT, "Trace execution and debug"],
  ['--force', '-f', GetoptLong::NO_ARGUMENT, "Force execution at checkpoints"],
  ['--quiet', '-q', GetoptLong::NO_ARGUMENT, "Suppress logging"]]

Tap::Support::CommandLine.handle_options(*opts) do |opt, value| 
  case opt
  when '--help'
    puts Tap::Support::CommandLine.command_help(__FILE__, opts)
    exit
    
  when '--quiet', '--force', '--debug'
    # simply track these have been set
    opt =~ /^-+(\w+)/
    app.options.send("#{$1}=", true)
  
  end
end

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
          env.log(:warn, "ignoring --help config for rake command") 
          true
        else
          false
        end
      end
 
      rake = env.rake_setup
    
      # takes the place of rake.top_level
      if rake.options.show_tasks
        rake.display_tasks_and_comments
        exit
      elsif rake.options.show_prereqs
        rake.display_prerequisites
        exit
      else
        rake.top_level_tasks.each do |task_name| 
          app.task(task_name).enq
        end
      end
      
    else  
      begin
        # attempt lookup the task class
        task_class = app.task_class(td)
      rescue(Tap::App::LookupError)
      end

      # unless a Tap::Task was found, treat the
      # args as a specification for Rake.
      if task_class == nil || !task_class.include?(Tap::Support::Configurable)
        env.log(:warn, "implicit rake: #{td}#{ARGV.empty? ? '' : ' ...'}", Logger::DEBUG)
        args.unshift('rake')
        redo
      end
    
      # now let the class handle the argv
      ARGV.collect! {|str| Tap::Support::CommandLine.parse_yaml(str) }
      ARGV.unshift(td)
      task_class.argv_enq(app)
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
