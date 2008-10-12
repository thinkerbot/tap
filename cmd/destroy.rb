require 'tap/generator/base'
require 'tap/generator/destroy'

env = Tap::Env.instance

if ARGV.empty? || ARGV == ['--help']
  puts env.summarize(:generators)
  exit
end

name = ARGV.shift
const = env.search(:generators, name) or raise "unknown generator: #{name}"

generator_class = const.constantize
generator, argv = generator_class.parse(ARGV)
generator.extend(Tap::Generator::Destroy).process(*argv)