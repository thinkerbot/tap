begin
  $:.unshift File.dirname(__FILE__) + "/../../../vendor"
  require 'tap/generator'
rescue(LoadError)
  puts "The 'rails' gem is required for generators -- install using:"
  puts "  % gem install rails"
  exit
end

Rails::Generator::Base.use_tap_sources!

require 'rails_generator/scripts/generate'
generator = ARGV.shift

# Ensure help is printed if help is the first argument
generator = nil if generator == '--help' || generator == '-h'

script = Rails::Generator::Scripts::Generate.new
script.extend Tap::Generator::Usage
script.run(ARGV, :generator => generator)
