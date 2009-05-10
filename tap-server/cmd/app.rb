# tap app {options}
#
# Launches an application server.
#

require 'tap'
require 'tap/server'
require 'tap/controllers/app'

env = Tap::Env.instance
app = Tap::App.instance
parser = ConfigParser.new do |opts|
  
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
argv = parser.parse!(ARGV, :add_defaults => false)

# launch server
config = parser.config.merge(:env => env, :app => app)
Tap::Server.new(Tap::Controllers::App, config).run!
