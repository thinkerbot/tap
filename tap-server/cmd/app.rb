# tap app {options}
#
# Launches an application server.
#

require 'tap'
require 'tap/constants'
require 'tap/app/server'

env = Tap::Env.instance
parser = ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"
  opts.add(Tap::App::Server.configurations)

  # add option to print help
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end
parser.parse!(ARGV)

# launch server
server = Tap::App::Server.new(parser.config)
server.run!
