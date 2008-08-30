# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"
require "tap/support/parsers/server"

server = Tap::Env.instance

require 'tap/tasks/dump'
task_attributes = {
  :identifier => "task",
  :tasc => Tap::Tasks::Dump,
  :config => {},
  :inputs => [],
  :index => 0
}

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out() do
  case cgi.request_method
  when /GET/i
    if cgi.params.empty?
      server.cgi_template('run',
        :server => server,
        :workflow => [],
        :workflow_actions => Tap::Support::Parsers::Base::WORKFLOW_ACTIONS,
        :tasks => [task_attributes])
    else
      "hllo"
    end
  when /POST/i
    
    # argh = UrlEncodedPairParser.new(cgi.params.to_a).result
    # queues = Tap::Support::Parsers::Server.new(argh).build(Tap::Env.instance, Tap::App.instance)
    
    # if queues.empty?
    # end
    
    # queues.each_with_index do |queue, i|
    #   app.queue.concat(queue)
    #   app.run
    # end
  else
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end