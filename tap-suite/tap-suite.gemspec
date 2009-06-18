Gem::Specification.new do |s|
  s.name = "tap-suite"
  s.version = "0.3.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A collection of modules to rapidly develop Tap workflows"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.18.0")
  s.add_dependency("rap", ">= 0.14.0")
  s.add_dependency("tap-gen", ">= 0.2.0")
  s.add_dependency("tap-server", ">= 0.5.0")
  s.add_dependency("tap-tasks", ">= 0.3.0")
  s.add_dependency("tap-test", ">= 0.2.0")
  s.rdoc_options.concat %W{--main README -S -N --title Tap-Suite}
  s.has_rdoc = false
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Tutorial}
  
  s.files = %W{}
end