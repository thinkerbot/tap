# usage: tap generate GENERATOR ...
#
# Runs a generator.  Each generator works a little differently; the best way to
# figure out what a generator does is to use --help. For example:
#
#   % tap generate root --help
#

require 'tap/generator/exe'
require 'tap/generator/generate'

env = Tap::Env.instance
env.extend Tap::Generator::Exe

env.run(Tap::Generator::Generate, ARGV) do
  puts Lazydoc.usage(__FILE__)
  puts
  puts "generators:"
  puts env.generators.summarize
  exit(1)
end