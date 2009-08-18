# usage: tap run [args] [options] -- [SCHEMA]
#
# examples:
#   tap run --help                     Prints this help
#   tap run -- task --help             Prints help for task
#   tap run -- load hello --: dump     Say hello
#

env = Tap::Env.instance
app = Tap::App.new
app.env = env

require 'tap/parser'

#
# parse argv
#

mode = :run
parser = Tap::Parser.new
config_parser = ConfigParser.bind(app.config) do |opts|
  opts.separator ""
  opts.separator "configurations:"
  
  root_keys = Tap::Root.configurations.keys
  Tap::App.configurations.each_pair do |key, config|
    next if root_keys.include?(key)
    opts.define(key, config.default, config.attributes)
  end
 
  opts.separator ""
  opts.separator "options:"
  
  opts.on("-h", "--help", "Show this message") do
    Tap::App.lazydoc.resolve
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit(0)
  end
  
  opts.on('-p', '--preview', 'Print the schema as YAML') do
    mode = :preview
  end
  
  opts.on('-s', '--schema FILE', 'Use the specifed schema') do |file|
    if schema
      puts "An inline schema cannot be specified with a file schema."
      exit(0)
    end
    
    schema = Tap::Schema.load_file(file)
  end
  
  opts.on('-t', '--manifest', 'Print a list of available resources') do
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
  
  opts.on('-T', '--tasks', 'Print a list of available tasks') do
    puts env.manifest(:task).summarize
    exit(0)
  end
  
  opts.on('-u', '--quick-queue', 'Removes thread-safety from queue') do
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

begin
  loop do
    break if ARGV.empty?

    config_parser.scan(ARGV) do |path|
      YAML.load_file(path).each do |spec|
        app.route(spec)
      end
    end

    break if ARGV.empty?
    
    ARGV.unshift("--")
    parser.parse!(ARGV)
    parser.build(app)
  end
  
  case mode
  when :run
    Tap::Exe.set_signals(app)
    app.run
  when :preview
    YAML.dump(app.to_schema, $stdout)
  end
  
rescue
  raise if app.debug?
  puts $!.message
  exit(1)
end

exit(0)