Gem::Specification.new do |s|
  s.name = "tap-suite"
  s.version = "0.1.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A framework for creating configurable, distributable tasks and workflows."
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.12.0")
  s.add_dependency("rap", ">= 0.12.0")
  s.has_rdoc = false
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Tutorial}
  
  s.files = %W{}
end