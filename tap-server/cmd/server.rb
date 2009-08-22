# tap server {options} 
#
# Initializes a tap server.
#

require 'tap'
require 'tap/server'

app = Tap::App.instance

begin
  opts = ConfigParser.new('app' => app)
  opts.separator ""
  opts.separator "configurations:"
  opts.add(Tap::Server.configurations)
  
  opts.separator ""
  opts.separator "options:"
  
  opts.on('--config FILE', 'Specifies a config file') do |config_file|
    opts.config.merge! Configurable::Utils.load_file(config_file)
  end
  
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
  
  # (note defaults are not added so they will not
  # conflict with string keys from a config file)
  args = opts.parse!(ARGV, :clear_config => false, :add_defaults => false)
  
  if args.empty?
    args << 'server'
  end
  
  controller = app.env[:controller][args.shift]
  
  unless args.empty?
    warn "ignoring args: #{args.inspect}"
  end
  
  Tap::Server.new(controller, opts.nested_config).run!
rescue
  raise if $DEBUG
  puts $!.message
  exit(1)
end

exit(0)


