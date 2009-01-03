# tap server {options}
#
# Initializes a tap server.

require 'tap'
require 'tap/support/gems/rack'

env = Tap::Env.instance

#
# handle options
#
options = {:Port => 8080}
ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on("-p", "--port PORT", "Specifies the port (default 8080)") do |value|
    options[:Port] = value.to_i
  end
  
  opts.on("-d", "--development", "Specifies development mode") do
    env.config[:development] = true
  end
  
end.parse!(ARGV)

#
# cgi dir and public dir can be set in tap.yml
#

env.extend Tap::Support::Gems::Rack
Rack::Handler::WEBrick.run(env, options) do |handler|
  env.handler = handler
end