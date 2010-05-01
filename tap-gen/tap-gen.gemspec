$:.unshift File.expand_path('../../tap/lib', __FILE__)
$:.unshift File.expand_path('../../tap-test/lib', __FILE__)
$:.unshift File.expand_path('../../tap-gen/lib', __FILE__)

require 'tap/version'
require 'tap/test/version'
require 'tap/generator/version'

Gem::Specification.new do |s|
  s.name = 'tap-gen'
  s.version = Tap::Generator::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = File.join(Tap::WEBSITE, 'tap-gen')
  s.platform = Gem::Platform::RUBY
  s.summary = 'Generators for Tap'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.add_dependency('tap', ">= #{Tap::VERSION}")
  s.add_development_dependency('tap-test', ">= #{Tap::Test::VERSION}")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap-Generator}
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    History
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    lib/tap/generator/arguments.rb
    lib/tap/generator/base.rb
    lib/tap/generator/destroy.rb
    lib/tap/generator/generate.rb
    lib/tap/generator/generators/config.rb
    lib/tap/generator/generators/env.rb
    lib/tap/generator/generators/generator.rb
    lib/tap/generator/generators/middleware.rb
    lib/tap/generator/generators/resource.rb
    lib/tap/generator/generators/root.rb
    lib/tap/generator/generators/tap.rb
    lib/tap/generator/generators/task.rb
    lib/tap/generator/helpers.rb
    lib/tap/generator/manifest.rb
    lib/tap/generator/preview.rb
    lib/tap/generator/version.rb
    tap-gen.gemspec
    tap.yml
    templates/tap/generator/generators/generator/resource.erb
    templates/tap/generator/generators/generator/test.erb
    templates/tap/generator/generators/middleware/resource.erb
    templates/tap/generator/generators/middleware/test.erb
    templates/tap/generator/generators/root/MIT-LICENSE
    templates/tap/generator/generators/root/README
    templates/tap/generator/generators/root/gemspec
    templates/tap/generator/generators/root/tap.yml
    templates/tap/generator/generators/root/tapfile
    templates/tap/generator/generators/root/test/tap_test_helper.rb
    templates/tap/generator/generators/tap/profile.erb
    templates/tap/generator/generators/tap/tap.erb
    templates/tap/generator/generators/task/resource.erb
    templates/tap/generator/generators/task/test.erb
  }
end