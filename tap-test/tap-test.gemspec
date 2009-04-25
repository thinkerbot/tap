Gem::Specification.new do |s|
  s.name = "tap-test"
  s.version = "0.0.1"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org/tap-test/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Test modules for Tap applications."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.17.0")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\sTest}
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    History
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    tap.yml
  }
end