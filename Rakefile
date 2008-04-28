require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$:.unshift "./lib"
require 'tap/constants'
require 'tap/patches/rake/testtask.rb'

desc 'Default: Run tests.'
task :default => :test

#
# Gem specification
#
Gem::manage_gems

spec = Gem::Specification.new do |s|
	s.name = "tap"
	s.version = Tap::VERSION
	s.author = "Simon Chiang"
	s.email = "simon.chiang@uchsc.edu"
	s.homepage = Tap::WEBSITE
	s.platform = Gem::Platform::RUBY
	s.summary = "A framework for configurable, distributable, and easy-to-use tasks and workflow applications."
	s.files = File.read("Manifest.txt").split("\n").select {|f| f !~ /^\s*#/ && !File.directory?(f) }
	s.require_path = "lib"
	s.rubyforge_project = "tap"
	s.test_file = "test/tap_test_suite.rb"
	s.bindir = "bin"
	s.executables = ["tap"]
  s.default_executable = "tap"
  
	s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap - Task Application' << '--main' << 'README' 
	s.extra_rdoc_files = ["README", "MIT-LICENSE", "History", "Tutorial", "Basic Overview", "Command Reference"]
  s.add_dependency("activesupport", ">=2.0.1")
end

Rake::GemPackageTask.new(spec) do |pkg|
	pkg.need_tar = true
end

desc 'Prints the gem manifest.'
task :print_manifest do
  spec.files.each do |file|
    puts file
  end
end

desc 'Run tests.'
Rake::TestTask.new(:test) do |t|
  t.test_files = if ENV['check']
    Dir.glob( File.join('test',  "**/*#{ENV['check']}*_check.rb") )
  else
    Dir.glob( File.join('test', ENV['pattern'] || '**/*_test.rb') ).delete_if do |filename|
      filename =~ /test\/check/
    end
  end
  
  t.verbose = true
  t.warning = true
end

#
# Documentation tasks
#

desc 'Generate documentation.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  require 'tap/support/tdoc'
  
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'tap'
  rdoc.template = 'tap/support/tdoc/tdoc_html_template' 
  rdoc.options << '--line-numbers' << '--inline-source' << '--fmt' << 'tdoc'
  rdoc.rdoc_files.include('README', 'MIT-LICENSE', "History", "Tutorial", "Basic Overview", "Command Reference")
  rdoc.rdoc_files.include('lib/tap/**/*.rb')
end

# desc 'Generate website.'
# task :website => [:rdoc] do |t|
#   require 'tap'
#   
#   # temporary
#   $: << File.dirname(__FILE__) + "/tap/simple_site/lib"
#   $: << File.dirname(__FILE__) + "/tap/ddb/lib"
#   Dependencies.load_paths << File.dirname(__FILE__) + "/tap/simple_site/lib"
#   Dependencies.load_paths << File.dirname(__FILE__) + "/tap/ddb/lib"
# 
#   require 'simple_site'
#   
#   app = Tap::App.instance
#   
#   app['pkg'] = "pkg/website-#{Tap::VERSION}"
#   app['content'] = 'website/content'
#   app['views'] = 'website/views'
#   app.enq 'simple_site/compile', '.'
#   app.run
#   
#   cp_r "rdoc", app.filepath('pkg', "rdoc")
# end

#
# Hoe tasks
#

desc 'Install the package as a gem'
task :install_gem => [:package] do
  sh "#{'sudo ' unless WINDOZE}gem install pkg/*.gem"
end

desc "Publish Website to RubyForge"
task :publish_website do
  require 'yaml'
  
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml")))
  host = "#{config["username"]}@rubyforge.org"
  
  rsync_args = "-v -c -r"
  remote_dir = "/var/www/gforge-projects/tap"
  local_dir = "pkg/website-#{Tap::VERSION}"
 
  sh %{rsync #{rsync_args} #{local_dir}/ #{host}:#{remote_dir}}
end

desc 'Show information about the gem.'
task :debug_gem do
  puts spec.to_ruby
end
