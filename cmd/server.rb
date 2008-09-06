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
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::TDoc.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on("-p", "--port PORT", Integer, "Specifies the port (default #{options[:Port]})") do |value|
    options[:Port] = value
  end
  
  opts.on("-d", "--development", Integer, "Specifies development mode") do
    env.config[:development] = true
  end
  
end.parse!(ARGV)

#
# cgi dir and public dir can be set in tap.yml
#

env.extend Tap::Support::Gems::Rack
Rack::Handler::WEBrick.run(env, options) do |handler|
  env.instance_variable_set(:@handler, handler)
end
