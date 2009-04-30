# tap app {options}
#
# Launches an application server.
#

require 'eventmachine'
require 'tap/constants'
require 'tap/app/server'

env = Tap::Env.instance
config = {:host => "127.0.0.1", :port => 8088}

#
# handle options
#

ConfigParser.new do |opts|
  opts.separator ""
  opts.separator "options:"
  
  opts.on("--host HOST", "The server host (#{config[:host]}).") do |input|
    config[:host] = input
  end
  
  opts.on("-p", "--port PORT", "The server port (#{config[:port]}).") do |input|
    config[:port] = input.to_i
  end
  
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end.parse!(ARGV)

#
# set signals and run
#

Signal.trap("INT") { 
  EventMachine::stop
}

EventMachine::run {
  EventMachine::start_server(config[:host], config[:port], Tap::App::Server, env)
  puts ">> Tap App Server: (tap-#{Tap::VERSION})"
  puts ">> Listening on #{config[:host]}:#{config[:port]}, CTRL+C to stop"
}
