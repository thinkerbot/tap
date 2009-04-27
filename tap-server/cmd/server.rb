# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/server'

env = Tap::Env.instance
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
argv = parser.parse(ARGV)

# launch server
Tap::Server.new(env, parser.config).run!
