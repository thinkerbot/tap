Gem::Specification.new do |s|
  s.name = "tap-tasks"
  s.version = "0.0.1"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http:/tap.rubyforge.org/tap-tasks/"
  s.platform = Gem::Platform::RUBY
  s.summary = "A set of standard Tap tasks"
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", "= 0.12.3")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\sTasks}
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    tap.yml
  }
end