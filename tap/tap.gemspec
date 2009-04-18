Gem::Specification.new do |s|
  s.name = "tap"
  s.version = "0.12.4"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A framework for creating configurable, distributable tasks and workflows."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.bindir = "bin"
  s.executables = "tap"
  s.add_dependency("configurable", ">= 0.4.1")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\s(Task\sApplication)}
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Class\sReference
    doc/Command\sReference
    doc/Syntax\sReference
    doc/Tutorial
    doc/examples/cmdline}
  
  s.files = %W{
    cmd/console.rb
    cmd/destroy.rb
    cmd/generate.rb
    cmd/manifest.rb
    cmd/run.rb
    bin/tap
    lib/tap.rb
    lib/tap/app.rb
    lib/tap/app/dependency.rb
    lib/tap/app/node.rb
    lib/tap/app/queue.rb
    lib/tap/app/state.rb
    lib/tap/app/tracer.rb
    lib/tap/constants.rb
    lib/tap/dump.rb
    lib/tap/env.rb
    lib/tap/env/constant.rb
    lib/tap/env/constant_manifest.rb
    lib/tap/env/gems.rb
    lib/tap/env/manifest.rb
    lib/tap/env/minimap.rb
    lib/tap/exe.rb
    lib/tap/generator/arguments.rb
    lib/tap/generator/base.rb
    lib/tap/generator/destroy.rb
    lib/tap/generator/generate.rb
    lib/tap/generator/generators/command/command_generator.rb
    lib/tap/generator/generators/command/templates/command.erb
    lib/tap/generator/generators/config/config_generator.rb
    lib/tap/generator/generators/generator/generator_generator.rb
    lib/tap/generator/generators/generator/templates/task.erb
    lib/tap/generator/generators/generator/templates/test.erb
    lib/tap/generator/generators/root/root_generator.rb
    lib/tap/generator/generators/root/templates/MIT-LICENSE
    lib/tap/generator/generators/root/templates/README
    lib/tap/generator/generators/root/templates/Rakefile
    lib/tap/generator/generators/root/templates/Rapfile
    lib/tap/generator/generators/root/templates/gemspec
    lib/tap/generator/generators/root/templates/test/tap_test_helper.rb
    lib/tap/generator/generators/task/task_generator.rb
    lib/tap/generator/generators/task/templates/task.erb
    lib/tap/generator/generators/task/templates/test.erb
    lib/tap/generator/manifest.rb
    lib/tap/generator/preview.rb
    lib/tap/join.rb
    lib/tap/joins.rb
    lib/tap/joins/switch.rb
    lib/tap/joins/sync.rb
    lib/tap/load.rb
    lib/tap/root.rb
    lib/tap/root/utils.rb
    lib/tap/root/versions.rb
    lib/tap/schema.rb
    lib/tap/schema/node.rb
    lib/tap/schema/parser.rb
    lib/tap/support/intern.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/string_ext.rb
    lib/tap/support/templater.rb
    lib/tap/task.rb
    lib/tap/tasks/file_task.rb
    }
end