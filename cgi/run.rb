# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"

cgi = CGI.new("html3")  # add HTML generation methods

# [ CGI.unescape(key), CGI.unescape(cgi[key]) ]
#pairs = cgi.keys.collect {|key| [key, cgi[key].to_s]}
UrlEncodedPairParser.new(cgi.params.to_a).result

cgi.out() do
  cgi.html() do
    cgi.head{ cgi.title{ "Tap::Run" } } +
    cgi.body() do
      cgi.pre do
        require 'pp'
        PP.singleline_pp(cgi.params, '') #+ 
        #UrlEncodedPairParser.new(pairs).result.to_yaml
      end
    end
  end
end
