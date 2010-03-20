Gem::Specification.new do |s|
  s.name = "rap"
  s.version = "1.0.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A rakish extension to tap."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 1.0.0")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Rap\s(Rakish\sApp)}
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Syntax\sReference
    }
  
  s.files = %W{
    lib/rap.rb
    lib/rap/declarations.rb
    lib/rap/task.rb
    lib/rap/version.rb
    }
end