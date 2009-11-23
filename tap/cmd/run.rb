# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#   tap run -- load hello --: dump     Say hello
#

require 'tap/parser'

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
  
  psr.on('-p', '--preview', 'Print the schema as YAML') do
    opts[:preview] = true
  end
  
  psr.on('-P', '--prompt', 'Enter the signal prompt') do
    opts[:prompt] = true
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
  
  psr.on('-e', '--require-enque', 'Require manual enque for tasks') do
    app.config[:auto_enque] = false
  end
end

#
# build and run
#

# A prompt to signal a running app. Any signals that return app (ie /run /stop
# /terminate) will exit the block.  Note that app should be running when the
# prompt is called so that a run signal defers to the running app and allows
# the prompt to exit.
prompt = lambda do
  require 'readline'
  
  puts "starting prompt (enter for help):"
  loop do
    begin
      line = Readline.readline('--/', true).strip
      next if line.empty?
      
      args = Shellwords.shellwords(line)
      "/#{args.shift}" =~ Tap::Parser::SIGNAL
      
      result = app.call('obj' => $1, 'sig' => $2, 'args' => args)
      if result == app
        break
      else
        puts "=> #{result}"
      end
    rescue
      puts $!.message
      puts $!.backtrace if app.debug?
    end
  end
end

# Traps interrupt the normal flow of the program and so I assume thread safety
# is an issue (ex if the INT occurs during an enque and a signal specifies
# another enque). A safer way to go is to enque the prompt... when the prompt
# is executed the app won't be be doing anything else so thread safety
# shouldn't be an issue.
Signal.trap('INT') do
  puts
  puts "Interrupt!  Note signals from an interruption are not thread-safe."
  
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
  
  if opts[:preview]
    YAML.dump(app.serialize, $stdout)
    exit(0)
  end
  
  if opts[:prompt]
    # ensures the app is running for the prompt
    app.queue.unshift(prompt, [])
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