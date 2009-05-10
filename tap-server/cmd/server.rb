# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/router'
require 'tap/controllers/server'

env = Tap::Env.instance
app = Tap::App.instance
parser = ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"
  opts.add(Tap::Router.configurations)

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
Tap::Router.new(Tap::Controllers::Server, config).run!
