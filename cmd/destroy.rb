require 'tap/generator/base'
require 'tap/generator/destroy'
require 'tap/support/command_line'

cmdline = Tap::Support::CommandLine
env = Tap::Env.instance

if ARGV.empty?
  puts env.summarize(:generators) {|const| const.document[const.name]['generator'] }
  exit
end

name = ARGV.shift
const = env.search(:generators, name) or raise "unknown generator: #{name}"

generator_class = const.constantize
generator, argv =  cmdline.instantiate(generator_class, ARGV)
generator.extend(Tap::Generator::Destroy).process(*argv)