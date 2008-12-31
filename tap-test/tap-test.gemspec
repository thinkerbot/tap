Gem::Specification.new do |s|
  s.name = "tap-test"
  s.version = "0.12.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "The standard tap test framework."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap-core", ">= 0.12.0")
  s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap Test' << '--main' << 'README' 
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    lib/tap/spec.rb
    lib/tap/test.rb
    lib/tap/test/assertions.rb
    lib/tap/test/env_vars.rb
    lib/tap/test/extensions.rb
    lib/tap/test/file_test.rb
    lib/tap/test/file_test_class.rb
    lib/tap/test/regexp_escape.rb
    lib/tap/test/script_test.rb
    lib/tap/test/script_tester.rb
    lib/tap/test/subset_test.rb
    lib/tap/test/subset_test_class.rb
    lib/tap/test/tap_test.rb
    lib/tap/test/utils.rb
    }
end