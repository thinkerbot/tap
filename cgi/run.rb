# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'
require 'yaml'
env = Tap::Env.instance

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out() do
  case cgi.request_method
  when /GET/i
    env.render('run.erb', :env => env)

  when /POST/i
    cgi.pre do
      Tap::Support::Schema.parse(cgi.params).dump.to_yaml
    end
  else 
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end