require File.expand_path('../../tap/lib/tap/version', __FILE__)
require File.expand_path('../../tap-test/lib/tap/test/version', __FILE__)
require File.expand_path('../lib/tap/tasks/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'tap-tasks'
  s.version = Tap::Tasks::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = File.join(Tap::WEBSITE, 'tap-tasks')
  s.platform = Gem::Platform::RUBY
  s.summary = 'A set of standard Tap tasks'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.add_dependency('tap', ">= #{Tap::VERSION}")
  s.add_development_dependency('tap-test', ">= #{Tap::Test::VERSION}")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap-Tasks}
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    History
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    lib/tap/tasks/insert.rb
    lib/tap/tasks/console.rb
    lib/tap/tasks/dump/csv.rb
    lib/tap/tasks/dump/inspect.rb
    lib/tap/tasks/dump/yaml.rb
    lib/tap/tasks/error.rb
    lib/tap/tasks/glob.rb
    lib/tap/tasks/load/csv.rb
    lib/tap/tasks/load/yaml.rb
    lib/tap/tasks/null.rb
    lib/tap/tasks/sleep.rb
    lib/tap/tasks/stream/yaml.rb
    lib/tap/tasks/version.rb
    tap-tasks.gemspec
    tap.yml
  }
end