# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/router'

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
Tap::Router.new(parser.config, env, app).run!
