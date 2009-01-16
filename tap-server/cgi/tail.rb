# ::summary
# runs a task
#
# ::description
# 
############################
require 'cgi'

env = Tap::Env.instance

# initialize with HTML generation methods
cgi = CGI.new("html3")  
cgi.out() do
  path = (cgi.params['path'] || [])[0]
  pos = (cgi.params['pos'] || [])[0].to_i
  
  params = {:env => env}
  case
  when path == nil
    params[:path] = nil
    params[:pos] = 0
    params[:content] = ""
  when File.exists?(path) # && permission
    params[:path] = path
    File.open(path) do |file|
      file.pos = pos
      params[:content] = file.read
      params[:pos] = file.pos
    end
  else
    raise "non-existant file: #{path}"
  end
  
  case cgi.request_method
  when /GET/i
    env.render('tail.erb', params)
  
  when /POST/i
    params[:content]
    
  else
    raise ArgumentError, "unhandled request method: #{cgi.request_method}"
  end
end
