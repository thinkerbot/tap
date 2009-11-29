Gem::Specification.new do |s|
  s.name = "tap-tasks"
  s.version = "0.5.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http:/tap.rubyforge.org/tap-tasks/"
  s.platform = Gem::Platform::RUBY
  s.summary = "A set of standard Tap tasks"
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.19.0")
  s.add_development_dependency("tap-test", ">= 0.3.0")
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
    lib/tap/joins/gate.rb
    lib/tap/middlewares/profiler.rb
    lib/tap/tasks/dump/csv.rb
    lib/tap/tasks/dump/inspect.rb
    lib/tap/tasks/dump/yaml.rb
    lib/tap/tasks/load/yaml.rb
    lib/tap/tasks/load/csv.rb
    lib/tap/tasks/null.rb
    lib/tap/tasks/glob.rb
    lib/tap/tasks/stream.rb
    lib/tap/tasks/stream/yaml.rb
    lib/tap/tasks/version.rb
    tap.yml
  }
end