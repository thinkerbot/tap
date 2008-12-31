Gem::Specification.new do |s|
  s.name = "tap-gen"
  s.version = "0.12.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "Tap generators."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap-core", ">= 0.12.0")
  s.add_development_dependency("tap-test", ">= 0.12.0")
  s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap Generators' << '--main' << 'README' 
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    cmd/destroy.rb
    cmd/generate.rb
    lib/tap/generator/arguments.rb
    lib/tap/generator/base.rb
    lib/tap/generator/destroy.rb
    lib/tap/generator/generate.rb
    lib/tap/generator/generators/command/command_generator.rb
    lib/tap/generator/generators/command/templates/command.erb
    lib/tap/generator/generators/config/config_generator.rb
    lib/tap/generator/generators/config/templates/doc.erb
    lib/tap/generator/generators/config/templates/nodoc.erb
    lib/tap/generator/generators/file_task/file_task_generator.rb
    lib/tap/generator/generators/file_task/templates/file.txt
    lib/tap/generator/generators/file_task/templates/result.yml
    lib/tap/generator/generators/file_task/templates/task.erb
    lib/tap/generator/generators/file_task/templates/test.erb
    lib/tap/generator/generators/generator/generator_generator.rb
    lib/tap/generator/generators/generator/templates/task.erb
    lib/tap/generator/generators/package/package_generator.rb
    lib/tap/generator/generators/package/templates/package.erb
    lib/tap/generator/generators/root/root_generator.rb
    lib/tap/generator/generators/root/templates/README
    lib/tap/generator/generators/root/templates/Rakefile
    lib/tap/generator/generators/root/templates/gemspec
    lib/tap/generator/generators/root/templates/tapfile
    lib/tap/generator/generators/root/templates/test/tap_test_helper.rb
    lib/tap/generator/generators/root/templates/test/tap_test_suite.rb
    lib/tap/generator/generators/task/task_generator.rb
    lib/tap/generator/generators/task/templates/task.erb
    lib/tap/generator/generators/task/templates/test.erb
    lib/tap/generator/manifest.rb
    tap.yml
    }
end