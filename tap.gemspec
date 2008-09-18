Gem::Specification.new do |s|
  s.name = "tap"
  s.version = "0.10.7"
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
    doc/Tutorial
    doc/Class\sReference
    doc/Command\sReference}
  
  s.files = %W{
    README
    MIT-LICENSE
    History
    cgi/run.rb
    cmd/console.rb
    cmd/destroy.rb
    cmd/generate.rb
    cmd/manifest.rb
    cmd/run.rb
    cmd/server.rb
    doc/Tutorial
    doc/Class\sReference
    doc/Command\sReference
    bin/rap
    bin/tap
    lib/tap/app.rb
    lib/tap/constants.rb
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
    lib/tap/generator/generators/root/root_generator.rb
    lib/tap/generator/generators/root/templates/README
    lib/tap/generator/generators/root/templates/Rakefile
    lib/tap/generator/generators/root/templates/tapfile
    lib/tap/generator/generators/root/templates/gemspec
    lib/tap/generator/generators/root/templates/test/tap_test_helper.rb
    lib/tap/generator/generators/root/templates/test/tap_test_suite.rb
    lib/tap/generator/generators/root/templates/test/tapfile_test.rb
    lib/tap/generator/generators/task/task_generator.rb
    lib/tap/generator/generators/task/templates/task.erb
    lib/tap/generator/generators/task/templates/test.erb
    lib/tap/generator/manifest.rb
    lib/tap/parser.rb
    lib/tap/patches/optparse/summarize.rb
    lib/tap/patches/rake/rake_test_loader.rb
    lib/tap/patches/rake/testtask.rb
    lib/tap/patches/ruby19/backtrace_filter.rb
    lib/tap/patches/ruby19/parsedate.rb
    lib/tap/root.rb
    lib/tap/spec.rb
    lib/tap/spec/adapter.rb
    lib/tap/spec/inheritable_class_test_root.rb
    lib/tap/support/aggregator.rb
    lib/tap/support/assignments.rb
    lib/tap/support/audit.rb
    lib/tap/support/batchable.rb
    lib/tap/support/batchable_class.rb
    lib/tap/support/class_configuration.rb
    lib/tap/support/combinator.rb
    lib/tap/support/configurable.rb
    lib/tap/support/configurable_class.rb
    lib/tap/support/configuration.rb
    lib/tap/support/constant.rb
    lib/tap/support/constant_utils.rb
    lib/tap/support/declarations.rb
    lib/tap/support/dependable.rb
    lib/tap/support/executable.rb
    lib/tap/support/executable_queue.rb
    lib/tap/support/gems/rake.rb
    lib/tap/support/gems/rack.rb
    lib/tap/support/gems.rb
    lib/tap/support/instance_configuration.rb
    lib/tap/support/lazy_attributes.rb
    lib/tap/support/lazydoc.rb
    lib/tap/support/lazydoc/comment.rb
    lib/tap/support/lazydoc/config.rb
    lib/tap/support/lazydoc/declaration.rb
    lib/tap/support/lazydoc/document.rb
    lib/tap/support/lazydoc/method.rb
    lib/tap/support/manifest.rb
    lib/tap/support/parsers/base.rb
    lib/tap/support/parsers/server.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/tdoc.rb
    lib/tap/support/tdoc/tdoc_html_generator.rb
    lib/tap/support/tdoc/tdoc_html_template.rb
    lib/tap/support/summary.rb
    lib/tap/support/templater.rb
    lib/tap/support/validation.rb
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
    lib/tap/workflow.rb
    lib/tap.rb
    template/404.erb
    template/index.erb
    vendor/url_encoded_pair_parser.rb
    }
end