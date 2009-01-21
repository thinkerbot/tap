require 'cgi'

env = Tap::Env.instance

# initialize with HTML generation methods
cgi = CGI.new  
cgi.out('text/plain') do
  schema = Tap::Server::Utils.parse_schema(cgi.params).compact
  env.render(:template, 'preview.erb', :schema => schema)
end