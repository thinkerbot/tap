Gem::Specification.new do |s|
  s.name = "tap"
  s.version = "0.12.3"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A framework for creating configurable, distributable tasks and workflows."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.bindir = "bin"
  s.executables = "tap"
  s.add_dependency("configurable", ">= 0.4.0")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\s(Task\sApplication)}
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Class\sReference
    doc/Command\sReference
    doc/Syntax\sReference
    doc/Tutorial}
  
  s.files = %W{
    cmd/console.rb
    cmd/destroy.rb
    cmd/generate.rb
    cmd/manifest.rb
    cmd/run.rb
    bin/tap
    lib/tap.rb
    lib/tap/app.rb
    lib/tap/constants.rb
    lib/tap/env.rb
    lib/tap/exe.rb
    lib/tap/file_task.rb
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
    lib/tap/root.rb
    lib/tap/spec.rb
    lib/tap/support/aggregator.rb
    lib/tap/support/audit.rb
    lib/tap/support/constant.rb
    lib/tap/support/constant_manifest.rb
    lib/tap/support/dependencies.rb
    lib/tap/support/dependency.rb
    lib/tap/support/executable.rb
    lib/tap/support/executable_queue.rb
    lib/tap/support/gems.rb
    lib/tap/support/intern.rb
    lib/tap/support/join.rb
    lib/tap/support/joins.rb
    lib/tap/support/joins/switch.rb
    lib/tap/support/joins/sync_merge.rb
    lib/tap/support/manifest.rb
    lib/tap/support/minimap.rb
    lib/tap/support/node.rb
    lib/tap/support/parser.rb
    lib/tap/support/schema.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/string_ext.rb
    lib/tap/support/templater.rb
    lib/tap/support/versions.rb
    lib/tap/task.rb
    lib/tap/tasks/core_dump.rb
    lib/tap/tasks/dump.rb
    lib/tap/tasks/load.rb
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