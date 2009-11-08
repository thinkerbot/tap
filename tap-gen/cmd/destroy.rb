# usage: tap destroy GENERATOR ...
#
# Runs a generator in reverse.  Each generator works a little differently; the
# best way to figure out what a generator does is to use --help. For example:
#
#   % tap generate root --help
#

require 'tap/generator/base'

app = Tap::App.instance

if ARGV.empty? || ARGV == ['--help']
  constants = app.env.constants
  generators = constants.summarize do |constant|
    constant.types['generator']
  end
  
  puts Lazydoc.usage(__FILE__)
  puts
  puts generators
  exit(1)
end

generator = app.build('class' => ARGV.shift, 'spec' => ARGV)
generator.signal(:set).call([Tap::Generator::Destroy])
generator.call(*ARGV)
