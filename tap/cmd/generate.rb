# usage: tap generate GENERATOR ...
#
# Runs a generator.  Each generator works a little differently; the best way to
# figure out what a generator does is to use --help. For example:
#
#   % tap generate root --help
#

require 'tap/generator/base'
require 'tap/generator/generate'

env = Tap::Env.instance

if ARGV.empty? || ARGV == ['--help']
  puts Lazydoc.usage(__FILE__)
  puts
  puts "generators:"
  puts env.summarize(:generators)
  exit
end

name = ARGV.shift
const = env.generators.search(name) or raise "unknown generator: #{name}"

generator_class = const.constantize
generator, argv = generator_class.parse(ARGV)
generator.extend(Tap::Generator::Generate).process(*argv)