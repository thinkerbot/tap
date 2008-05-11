# = Usage
# tap console {options}
#
# = Description
# Opens up an IRB session with Tap initialized with configurations 
# in tap.yml. Access the Tap::App.instance through 'app'
#

#
# handle options
#

opts = [
  ['--help', '-h', GetoptLong::NO_ARGUMENT, "Print this help."]]
  
Tap::Support::CommandLine.handle_options(*opts) do |opt, value| 
  case opt
  when '--help'
    puts Tap::Support::CommandLine.command_help(__FILE__, opts)
    exit

  end
end

require "irb"

def app
  Tap::App.instance
end

def env
  Tap::Env.instance
end

IRB.start