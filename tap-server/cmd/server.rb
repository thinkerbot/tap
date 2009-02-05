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
end

# parse!
argv = opts.parse(ARGV)
server = Tap::Server.new(env, opts.config)
Rack::Handler::WEBrick.run(server, :Port => server.port) # host...
