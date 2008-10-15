# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require "#{File.dirname(__FILE__)}/../vendor/url_encoded_pair_parser"

env = Tap::Env.instance

# Sample::manifest summary
#
# A longer description of the
# Sample Task.
class Sample < Tap::Task
  config :one, '1' # the one config
  config :two, '2'
  
  def process(one, two, *three)
  end
end

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out() do
  case cgi.request_method
  when /GET/i
    env.render('run.erb', :env => env, :tasc => Sample )

  when /POST/i
    cgi.pre do
      pairs = {}
      cgi.params.each_pair do |key, values|
        key = key.chomp("%w") if key =~ /%w$/

        slot = pairs[key] ||= []
        values.each do |value|
          value = value.respond_to?(:read) ? value.read : value
          if $~ 
            slot.concat(Shellwords.shellwords(value))
          else 
            slot << value
          end
        end
      end
      
      argh = UrlEncodedPairParser.new(pairs).result
      Tap::Support::Schema.parse(argh['schema']).dump.to_yaml
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end