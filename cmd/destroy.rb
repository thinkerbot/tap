require 'tap/generator/base'
require 'tap/generator/destroy'

env = Tap::Env.instance

if ARGV.empty?
  puts env.summarize(:generators) {|const| const.document[const.name]['generator'] }
  exit
end

name = ARGV.shift
const = env.search(:generators, name) or raise "unknown generator: #{name}"

generator_class = const.constantize
generator, argv = generator_class.argv_new(ARGV)
generator.extend(Tap::Generator::Destroy).process(*argv)