Gem::Specification.new do |s|
	s.name = "tap"
  s.version = "0.10.0"
	s.author = "Simon Chiang"
	s.email = "simon.chiang@uchsc.edu"
  s.homepage = "http://tap.rubyforge.org"
	s.platform = Gem::Platform::RUBY
	s.summary = "A framework for configurable, distributable, and easy-to-use tasks and workflow applications."
	s.require_path = "lib"
	s.rubyforge_project = "tap"
	#s.test_file = "test/tap_test_suite.rb"
	s.bindir = "bin"
	s.executables = ["tap"]
  s.default_executable = "tap"
	s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap - Task Application' << '--main' << 'README' 
	s.extra_rdoc_files = %W{
	  README
	  MIT-LICENSE
	  History
	  doc/Tutorial
	  doc/Basic\sOverview
	  doc/Command\sReference}
	
	s.files = %W{
	  README
    MIT-LICENSE
    History
    cmd/console.rb
    cmd/destroy.rb
    cmd/generate.rb
    cmd/run.rb
    doc/Tutorial
    doc/Basic\sOverview
    doc/Command\sReference
    Rakefile
    bin/tap
    lib/tap/app.rb
    lib/tap/constants.rb
    lib/tap/dump.rb
    lib/tap/env.rb
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
    lib/tap/generator/generators/root/templates/Rakefile
    lib/tap/generator/generators/root/templates/MIT-LICENSE
    lib/tap/generator/generators/root/templates/README
    lib/tap/generator/generators/root/templates/gemspec
    lib/tap/generator/generators/root/templates/test/tap_test_helper.rb
    lib/tap/generator/generators/root/templates/test/tap_test_suite.rb
    lib/tap/generator/generators/task/task_generator.rb
    lib/tap/generator/generators/task/templates/task.erb
    lib/tap/generator/generators/task/templates/test.erb
    lib/tap/generator/manifest.rb
    lib/tap/patches/rake/rake_test_loader.rb
    lib/tap/patches/rake/testtask.rb
    lib/tap/patches/ruby19/backtrace_filter.rb
    lib/tap/patches/ruby19/parsedate.rb
    lib/tap/root.rb
    lib/tap/support/aggregator.rb
    lib/tap/support/assignments.rb
    lib/tap/support/audit.rb
    lib/tap/support/batchable.rb
    lib/tap/support/batchable_methods.rb
    lib/tap/support/class_configuration.rb
    lib/tap/support/command_line.rb
    lib/tap/support/comment.rb
    lib/tap/support/configurable.rb
    lib/tap/support/configurable_methods.rb
    lib/tap/support/configuration.rb
    lib/tap/support/constant.rb
    lib/tap/support/dependencies.rb
    lib/tap/support/executable.rb
    lib/tap/support/executable_queue.rb
    lib/tap/support/framework.rb
    lib/tap/support/framework_methods.rb
    lib/tap/support/instance_configuration.rb
    lib/tap/support/lazydoc.rb
    lib/tap/support/logger.rb
    lib/tap/support/rake.rb
    lib/tap/support/run_error.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/tdoc/config_attr.rb
    lib/tap/support/tdoc/tdoc_html_generator.rb
    lib/tap/support/tdoc/tdoc_html_template.rb
    lib/tap/support/summary.rb
    lib/tap/support/templater.rb
    lib/tap/support/validation.rb
    lib/tap/support/versions.rb
    lib/tap/task.rb
    lib/tap/test/env_vars.rb
    lib/tap/test/file_methods.rb
    lib/tap/test/script_methods.rb
    lib/tap/test/subset_methods.rb
    lib/tap/test/tap_methods.rb
    lib/tap/test.rb
    lib/tap/workflow.rb
    lib/tap.rb
    vendor/blank_slate.rb
    }
end