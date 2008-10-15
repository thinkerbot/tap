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
    cgi.pre do
      pairs = {}
      cgi.params.each_pair do |key, values|
        key = key.chomp("-") if key =~ /(]-)$/
        raise "collision: #{key}" if pairs[key]
        
        pairs[key] = values.collect do |value|
          value = value.respond_to?(:read) ? value.read : value
          $1 ? Shellwords.shellwords(value) : value
        end
      end
      
      argh = UrlEncodedPairParser.new(pairs).result
      Tap::Support::Schema.parse(argh['schema']).dump.to_yaml
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end