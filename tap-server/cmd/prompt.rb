# tap prompt {options} 
#
# Launches a prompt to interact with an app server.
#

require 'eventmachine'
require 'tap/constants'
require 'tap/app/server'
require 'tap/app/client'

env = Tap::Env.instance
config = {:host => "127.0.0.1", :port => 8088, :app => true}

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
  
  opts.on("-a", "--[no-]app", "Launch the app server (true).") do |input|
    config[:app] = input
  end
  
  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end.parse!(ARGV)

module Prompt
  include EM::Protocols::LineText2
  
  attr_reader :client
  
  def initialize(client)
    @client = client
  end
  
  def receive_line(data)
    client.send_data(data)
    $stdout.print "> "
    $stdout.flush
  end
end

#
# set signals and run
#

Signal.trap("INT") { 
  EventMachine::stop
}

EventMachine::run {
  if config[:app]
    EventMachine::start_server(config[:host], config[:port], Tap::App::Server, env)
    puts ">> Tap App Server: (tap-#{Tap::VERSION})"
    puts ">> Listening on #{config[:host]}:#{config[:port]}, CTRL+C to stop"
  end
  
  client = EventMachine::connect(config[:host], config[:port], Tap::App::Client)
  EventMachine::open_keyboard(Prompt, client)
  puts ">> Tap App Prompt: (tap-#{Tap::VERSION})"
  puts ">> Connected to #{config[:host]}:#{config[:port]}, CTRL+C to stop"
  print "> "
  $stdout.flush
}
