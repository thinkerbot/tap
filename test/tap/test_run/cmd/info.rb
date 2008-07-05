# = Usage
# tap info {options} ARGS...
#
# = Description
# The default command simply prints the input arguments 
# and application information, then exits.
#

require 'tap'

app = Tap::App.instance   

#
# handle options
#

opts = [
  ['--help', '-h', GetoptLong::NO_ARGUMENT, "Print this help."],
  ['--debug', nil, GetoptLong::NO_ARGUMENT, "Specifies debug mode."]]
  
Tap::Support::CommandLine.handle_options(*opts) do |opt, value| 
  case opt
  when '--help'
    puts Tap::Support::CommandLine.command_help(__FILE__, opts)
    exit
    
  when '--debug'
    app.options.debug = true

  end
end

#
# add your script code here
#

puts "Received: #{ARGV.join(', ')}"
puts app.info