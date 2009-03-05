# usage: tap console [options]
#
# Opens up an IRB session with the Tap environment initialized as specified
# in tap.yml. Access the Tap::App.instance through 'app', and
# Tap::Env.instance through 'env'.  For example:
#
#   % tap console
#   >> env.tasks.search('tap:dump').constantize=> Tap::Tasks::Dump
#   >> app.info
#   => "state: 0 (READY) queue: 0 results: 0"
#   >> 
#

ConfigParser.new do |opts|
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end.parse!(ARGV)

require "irb"

def app
  Tap::App.instance
end

def env
  Tap::Env.instance
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