# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/server'
require 'tap/controllers/server'

env = Tap::Env.instance
app = Tap::App.instance

server, args = Tap::Server.parse!(ARGV) do |opts|
  
  # add option to print help
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end

controller = lambda {|env| [200, {}, ['hello']] }
server.run!(controller)
