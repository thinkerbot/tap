# usage: tap destroy GENERATOR ...
#
# Runs a generator in reverse.  Each generator works a little differently; the
# best way to figure out what a generator does is to use --help. For example:
#
#   % tap generate root --help
#

require 'tap/generator/exe'
require 'tap/generator/destroy'

env = Tap::Env.instance
env.extend Tap::Generator::Exe

env.run(Tap::Generator::Destroy, ARGV) do
  puts Lazydoc.usage(__FILE__)
  puts
  puts "generators:"
  puts env.manifest('generator').summarize
  exit(1)
end
