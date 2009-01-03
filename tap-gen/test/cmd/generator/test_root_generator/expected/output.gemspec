Gem::Specification.new do |s|
  s.name = "output"
  s.version = "0.0.1"
  #s.author = "Your Name Here"
  #s.email = "your.email@pubfactory.edu"
  #s.homepage = "http://rubyforge.org/projects/output/"
  s.platform = Gem::Platform::RUBY
  s.summary = "output"
  s.require_path = "lib"
  s.test_file = "test/tap_test_suite.rb"
  #s.rubyforge_project = "output"
  #s.has_rdoc = true
  s.add_dependency("tap", "= 0.12.0")
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    tap.yml
    test/tap_test_helper.rb
    test/tap_test_suite.rb
  }
end