Gem::Specification.new do |s|
  s.name = "tap-test"
  s.version = "0.0.1"
  #s.author = "Your Name Here"
  #s.email = "your.email@pubfactory.edu"
  #s.homepage = "http://rubyforge.org/projects/tap-test/"
  s.platform = Gem::Platform::RUBY
  s.summary = "tap-test"
  s.require_path = "lib"
  #s.rubyforge_project = "tap-test"
  s.add_dependency("tap", "= 0.12.4")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap-test}
  
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