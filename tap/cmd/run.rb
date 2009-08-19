# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#   tap run -- load hello --: dump     Say hello
#

require 'tap/parser'

app = Tap::App.new
mode = nil
auto_enque = true
parser = ConfigParser.bind(app.config) do |psr|
  psr.separator ""
  psr.separator "configurations:"
  
  root_keys = Tap::Root.configurations.keys
  Tap::App.configurations.each_pair do |key, config|
    next if root_keys.include?(key)
    psr.define(key, config.default, config.attributes)
  end
 
  psr.separator ""
  psr.separator "options:"
  
  psr.on("-h", "--help", "Show this message") do
    Tap::App.lazydoc.resolve
    puts Lazydoc.usage(__FILE__)
    puts psr
    exit(0)
  end
  
  psr.on('-p', '--preview', 'Print the schema as YAML') do
    mode = :preview
  end
  
  psr.on('-t', '--manifest', 'Print a list of available resources') do
    env = app.env
    
    tasks = env.manifest(:task)
    tasks_found = !tasks.all_empty?
    
    joins = env.manifest(:join)
    joins_found = !joins.all_empty?
    
    middleware = env.manifest(:middleware)
    middleware_found = !middleware.all_empty?
    
    if tasks_found 
      puts "=== tasks ===" if middleware_found || joins_found
      puts tasks.summarize
    end

    if joins_found
      puts "=== joins ===" if tasks_found || middleware_found
      puts joins.summarize
    end
    
    if middleware_found
      puts "=== middleware ===" if tasks_found || joins_found
      puts middleware.summarize
    end
    
    exit(0)
  end
  
  psr.on('-T', '--tasks', 'Print a list of available tasks') do
    puts app.env.manifest(:task).summarize
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
    auto_enque = false
  end
end

#
# build and run
#

begin
  loop do
    break if ARGV.empty?

    parser.scan(ARGV) do |path|
      YAML.load_file(path).each do |spec|
        app.route(spec)
      end
    end

    break if ARGV.empty?
    
    ARGV.unshift("--")
    Tap::Parser.parse!(ARGV).build(app, auto_enque)
  end
  
  case mode
  when :preview
    YAML.dump(app.to_schema, $stdout)
  else
    app.run
  end
  
rescue
  raise if app.debug?
  puts $!.message
  exit(1)
end

exit(0)