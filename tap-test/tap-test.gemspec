$:.unshift File.expand_path('../../tap/lib', __FILE__)
$:.unshift File.expand_path('../../tap-test/lib', __FILE__)

require 'tap/version'
require 'tap/test/version'

$:.shift
$:.shift

Gem::Specification.new do |s|
  s.name = 'tap-test'
  s.version = Tap::Test::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = File.join(Tap::WEBSITE, 'tap-test')
  s.platform = Gem::Platform::RUBY
  s.summary = 'Test modules for Tap'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap-Test}
  
  s.add_dependency('tap', ">= #{Tap::VERSION}")
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    History
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    lib/tap/test.rb
    lib/tap/test/env.rb
    lib/tap/test/file_test.rb
    lib/tap/test/file_test/class_methods.rb
    lib/tap/test/shell_test.rb
    lib/tap/test/shell_test/regexp_escape.rb
    lib/tap/test/subset_test.rb
    lib/tap/test/subset_test/class_methods.rb
    lib/tap/test/tap_test.rb
    lib/tap/test/tracer.rb
    lib/tap/test/unit.rb
    lib/tap/test/utils.rb
    lib/tap/test/version.rb
  }
end