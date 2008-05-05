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

IRB.start

# Handles a bug in IRB that causes exit to throw :IRB_EXIT
# and consequentially make a warning message, even on a 
# clean exit.  This module resets exit to the original 
# aliased method.
module CleanExit # :nodoc:
  def exit(ret = 0)
    __exit__(ret)
  end
end
IRB.CurrentContext.extend CleanExit
