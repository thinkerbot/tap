# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/server'

env = Tap::Env.instance
app = Tap::App.instance

#
# handle options
#

config_path = nil
opts = ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"
  opts.add(Tap::Server.configurations)

  # add option to print help
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end

  # add option to specify a config file
  opts.on('--config FILE', 'Specifies a config file') do |value|
    config_path = value
  end
end

# parse!
argv = opts.parse(ARGV)

# load configurations
config_path ||= app.filepath('config', "server.yml")
configs = Tap::Server.load_config(config_path)
configs[:env] = env

server = Tap::Server.new(configs).reconfigure(opts.config)
Rack::Handler::WEBrick.run(server, :Port => server.port) # host...
