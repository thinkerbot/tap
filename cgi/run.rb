require "cgi"

cgi = CGI.new("html3")  # add HTML generation methods
cgi.out("text/plain") do

  "run"
end