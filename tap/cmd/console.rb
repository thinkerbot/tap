# usage: tap console [options]
#
# Opens up an IRB session with the Tap environment initialized as specified
# in tap.yml. Access a Tap::App instance through 'app' and the execution
# environment through 'env'.  For example:
#
#   % tap console
#   >> env.tasks['tap/dump']
#   => Tap::Dump
#   >> app.info
#   => "state: 0 (READY) queue: 0"
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
  @app ||= Tap::App.new
end

def env
  @env ||= Tap::Env.instance
end

def run(cmd, reset=true)
  app.reset if reset
  schema = Tap::Schema.parse(cmd)
  env.run(schema, app)
  nil
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