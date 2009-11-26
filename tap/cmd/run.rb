# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#   tap run -- load hello --: dump     Say hello
#

app = Tap::App.instance

opts = {}
parser = ConfigParser.bind(app.config) do |psr|
  psr.separator ""
  psr.separator "configurations:"
  
  psr.add Tap::App.configurations
  
  psr.separator ""
  psr.separator "options:"
  
  psr.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts psr
    exit(0)
  end
  
  psr.on('-s', '--serialize', 'Serialize the workflow') do
    opts[:serialize] = true
  end
  
  psr.on('-t', '--manifest', 'Print a list of available resources') do
    constants = app.env.constants
    
    tasks, joins, middleware = %w{task join middleware}.collect do |type|
      constants.summarize do |constant|
        constant.types[type]
      end
    end
    
    unless tasks.empty? 
      puts "=== tasks ===" unless middleware.empty? && joins.empty?
      puts tasks
    end

    unless joins.empty?
      puts "=== joins ===" unless tasks.empty? && middleware.empty?
      puts joins
    end
    
    unless middleware.empty?
      puts "=== middleware ===" unless tasks.empty? && joins.empty?
      puts middleware
    end
    
    exit(0)
  end
  
  psr.on('-T', '--tasks', 'Print a list of available tasks') do
    constants = app.env.constants
    tasks = constants.summarize do |constant|
      constant.types['task']
    end
    
    puts tasks
    exit(0)
  end
  
  psr.on('-u', '--quick-queue', 'Removes thread-safety from queue') do
    mod = Module.new do
      def synchronize
        yield
      end
    end
    app.queue.extend(mod)
  end
end

#
# build and run
#

# Traps interrupt the normal flow of the program and so I assume thread safety
# is an issue (ex if the INT occurs during an enque and a signal specifies
# another enque). A safer way to go is to enque the prompt... when the prompt
# is executed the app won't be be doing anything else so thread safety
# shouldn't be an issue.
Signal.trap('INT') do
  puts
  puts "Interrupt!  Signals from an interruption are not thread-safe."
  
  require 'tap/prompt'
  prompt = Tap::Prompt.new
  call_prompt = true
  3.times do
    print "Wait for thread-safe break? (y/n): "
    
    case gets.strip
    when /^y(es)?$/i
      puts "waiting for break..."
      app.queue.unshift(prompt, [])
      call_prompt = false
      break
      
    when /^no?$/i
      break
    end
  end
  
  if call_prompt
    prompt.call
  end
end

begin
  loop do
    break if ARGV.empty?
    parser.scan(ARGV, 
      :option_break => Tap::Parser::BREAK,
      :keep_break => true
    ) do |path|
      YAML.load_file(path).each do |spec|
        app.call(spec)
      end
    end

    break if ARGV.empty?
    ARGV.replace app.call('sig' => 'parse', 'args' => ARGV)
  end
  
  if opts[:serialize]
    YAML.dump(app.serialize, $stdout)
    exit(0)
  end
  
  opts = nil
  parser = nil
  app.run
  
rescue
  raise if app.debug?
  puts $!.message
  exit(1)
end

exit(0)