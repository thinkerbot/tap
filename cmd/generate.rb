require 'tap/generator/base'
require 'tap/generator/generate'

env = Tap::Env.instance

if ARGV.empty? || ARGV == ['-T']
  puts env.summarize(:generators) {|const| const.document[const.name]['generator'] }
  exit
end

name = ARGV.shift
const = env.search(:generators, name) or raise "unknown generator: #{name}"

generator_class = const.constantize
generator, argv = generator_class.parse(ARGV)
generator.extend(Tap::Generator::Generate).process(*argv)