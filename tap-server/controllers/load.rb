require 'cgi'

env = Tap::Env.instance

# initialize with HTML generation methods
cgi = CGI.new("html3")
cgi.out do
  argv = YAML.load(cgi.params['yaml'][0].read)
  
  # parse a schema and clean it up using compact
  schema = Tap::Support::Schema.parse(argv.flatten).compact
  env.render(:template, 'run.erb', :schema => schema)
end