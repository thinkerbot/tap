Gem::Specification.new do |s|
  s.name = "tap-gen"
  s.version = "0.2.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org/tap-gen"
  s.platform = Gem::Platform::RUBY
  s.summary = "Generators for Tap"
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.18.0")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap-Generator}
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    History
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rap print_manifest'
  s.files = %W{
    cmd/destroy.rb
    cmd/generate.rb
    lib/tap/generator/arguments.rb
    lib/tap/generator/base.rb
    lib/tap/generator/destroy.rb
    lib/tap/generator/exe.rb
    lib/tap/generator/generate.rb
    lib/tap/generator/generators/command.rb
    lib/tap/generator/generators/config.rb
    lib/tap/generator/generators/generator.rb
    lib/tap/generator/generators/middleware.rb
    lib/tap/generator/generators/resource.rb
    lib/tap/generator/generators/root.rb
    lib/tap/generator/generators/task.rb
    lib/tap/generator/manifest.rb
    lib/tap/generator/preview.rb
    tap.yml
    templates/tap/generator/generators/command/command.erb
    templates/tap/generator/generators/generator/resource.erb
    templates/tap/generator/generators/generator/test.erb
    templates/tap/generator/generators/middleware/resource.erb
    templates/tap/generator/generators/middleware/test.erb
    templates/tap/generator/generators/root/MIT-LICENSE
    templates/tap/generator/generators/root/README
    templates/tap/generator/generators/root/Rakefile
    templates/tap/generator/generators/root/Rapfile
    templates/tap/generator/generators/root/gemspec
    templates/tap/generator/generators/root/test/tap_test_helper.rb
    templates/tap/generator/generators/task/resource.erb
    templates/tap/generator/generators/task/test.erb
  }
end