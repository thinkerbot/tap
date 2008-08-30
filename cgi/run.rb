# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"
require "tap/support/parsers/server"

cgi = CGI.new("html3")  # add HTML generation methods

argh = UrlEncodedPairParser.new(cgi.params.to_a).result
queues = Tap::Support::Parsers::Server.new(argh).build(Tap::Env.instance, Tap::App.instance)

cgi.out() do
  cgi.html() do
    cgi.head{ cgi.title{ "Tap::Run" } } +
    cgi.body() do
      cgi.pre do
        if queues.empty?
          
          "b;ah"
        else
          
          queues.each_with_index do |queue, i|
            app.queue.concat(queue)
            app.run
          end
          
          "Ran"
        end
      end
    end
  end
end
