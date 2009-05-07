# tap app {options}
#
# Launches an application server.
#

require 'tap'
require 'tap/constants'
require 'tap/app/server'
require 'tap/exe/opts'

env = Tap::Env.instance
parser = ConfigParser.new
parser.separator ""
parser.separator "server:"
parser.add(Tap::App::Server.configurations)

# set options
Tap::Exe::Opts.parse!(ARGV) do |opts|
  puts Lazydoc.usage(__FILE__)
  puts parser
  puts opts
  exit
end

# launch server
parser.parse!(ARGV, 
  :add_defaults => false, 
  :ignore_unknown_options => true)
server = Tap::App::Server.new(parser.config)
server.run!
