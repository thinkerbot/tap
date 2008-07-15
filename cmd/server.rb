# TODO -- fix --help so that true server help is displayed

# change to the server dir so that script/server launches as normal
# (otherwise Mongrel can raise errors because it can't find a log file)
Dir.chdir Tap::App.instance[:server]

server_script = "script/server"
unless File.exists?(server_script)
  puts "server script does not exist: #{Tap::App.instance.filepath(:server, server_script)}"
  puts "no tap server available?"
  exit
end

load server_script