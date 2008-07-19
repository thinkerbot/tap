require 'tap/generator/base'
require 'tap/generator/destroy'

env = Tap::Env.instance

if ARGV.empty?
  puts env.summarize(:generators) {|const| const.document['']['generator'] }
  exit
end

name = ARGV.shift
const = env.search(:generators, name) or raise "unknown generator: #{name}"

generator_class = const.constantize
name, config, argv = generator_class.parse_argv(ARGV)
generator_class.new(name, config).extend(Tap::Generator::Destroy).process(*argv)