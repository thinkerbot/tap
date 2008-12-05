Gem::Specification.new do |s|
  s.name = "tap"
  s.version = "0.12.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A framework for creating configurable, distributable tasks and workflows."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.bindir = "bin"
  s.executables = ["tap", "rap"]
  s.default_executable = "tap"
  s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap - Task Application' << '--main' << 'README' 
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Class\sReference
    doc/Command\sReference
    doc/Syntax\sReference
    doc/Tutorial}
  
  s.files = %W{
    cgi/run.rb
    cmd/console.rb
    cmd/destroy.rb
    cmd/generate.rb
    cmd/manifest.rb
    cmd/server.rb
    cmd/run.rb
    doc/Tutorial
    doc/Class\sReference
    doc/Command\sReference
    bin/rap
    bin/tap
    lib/tap/app.rb
    lib/tap/constants.rb
    lib/tap/declarations.rb
    lib/tap/env.rb
    lib/tap/exe.rb
    lib/tap/file_task.rb
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
    lib/tap/generator/generators/root/root_generator.rb
    lib/tap/generator/generators/root/templates/README
    lib/tap/generator/generators/root/templates/Rakefile
    lib/tap/generator/generators/root/templates/tapfile
    lib/tap/generator/generators/root/templates/gemspec
    lib/tap/generator/generators/root/templates/test/tap_test_helper.rb
    lib/tap/generator/generators/root/templates/test/tap_test_suite.rb
    lib/tap/generator/generators/task/task_generator.rb
    lib/tap/generator/generators/task/templates/task.erb
    lib/tap/generator/generators/task/templates/test.erb
    lib/tap/generator/manifest.rb
    lib/tap/root.rb
    lib/tap/spec.rb
    lib/tap/support/aggregator.rb
    lib/tap/support/audit.rb
    lib/tap/support/combinator.rb
    lib/tap/support/constant.rb
    lib/tap/support/constant_manifest.rb
    lib/tap/support/dependencies.rb
    lib/tap/support/dependency.rb
    lib/tap/support/executable.rb
    lib/tap/support/executable_queue.rb
    lib/tap/support/gems/rack.rb
    lib/tap/support/gems/rake.rb
    lib/tap/support/gems.rb
    lib/tap/support/intern.rb
    lib/tap/support/join.rb
    lib/tap/support/joins.rb
    lib/tap/support/joins/fork.rb
    lib/tap/support/joins/merge.rb
    lib/tap/support/joins/sequence.rb
    lib/tap/support/joins/switch.rb
    lib/tap/support/joins/sync_merge.rb
    lib/tap/support/manifest.rb
    lib/tap/support/minimap.rb
    lib/tap/support/node.rb
    lib/tap/support/parser.rb
    lib/tap/support/schema.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/string_ext.rb
    lib/tap/support/tdoc.rb
    lib/tap/support/tdoc/tdoc_html_generator.rb
    lib/tap/support/tdoc/tdoc_html_template.rb
    lib/tap/support/templater.rb
    lib/tap/support/versions.rb
    lib/tap/task.rb
    lib/tap/tasks/dump.rb
    lib/tap/tasks/load.rb
    lib/tap/tasks/rake.rb
    lib/tap/test/assertions.rb
    lib/tap/test/env_vars.rb
    lib/tap/test/extensions.rb
    lib/tap/test/file_test.rb
    lib/tap/test/file_test_class.rb
    lib/tap/test/script_test.rb
    lib/tap/test/regexp_escape.rb
    lib/tap/test/script_tester.rb
    lib/tap/test/subset_test.rb
    lib/tap/test/subset_test_class.rb
    lib/tap/test/tap_test.rb
    lib/tap/test/utils.rb
    lib/tap/test.rb
    lib/tap.rb
    public/javascripts/prototype.js
    public/javascripts/run.js
    public/stylesheets/run.css
    template/404.erb
    template/index.erb
    template/run.erb
    template/run/join.erb
    template/run/manifest.erb
    template/run/node.erb
    template/run/round.erb
    vendor/url_encoded_pair_parser.rb
    }
end