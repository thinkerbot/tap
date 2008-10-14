# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"
env = Tap::Env.instance

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out() do
  case cgi.request_method
  when /GET/i
    env.render('run.erb', :env => env)

  when /POST/i
    #argv = []
    argh = UrlEncodedPairParser.new(cgi.params.to_a).result
    
    "<pre>\n" +
    argh.inspect + 
    #Tap::Support::Schema.parse(argv).dump.to_yaml +
    "</pre>"
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end