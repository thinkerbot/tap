require 'tap/generator/base'
require 'tap/generator/generate'

env = Tap::Env.instance

if ARGV.empty?
  puts env.summarize(:generators) {|const| const.document['']['generator'] }
  exit
end

td = ARGV.shift
const = env.search(:generators, td) or raise "unknown generator: #{td}"

generator = const.constantize.new
generator.extend(Tap::Generator::Generate)
generator.enq(*ARGV)

generator.app.run

# Rails::Generator::Base.use_env_sources!
# 
# require 'rails_generator/scripts/generate'
# generator = ARGV.shift
# 
# # Ensure help is printed if help is the first argument
# generator = nil if generator == '--help' || generator == '-h'
# 
# script = Rails::Generator::Scripts::Generate.new
# script.extend Tap::Generator::Usage
# script.run(ARGV, :generator => generator)
