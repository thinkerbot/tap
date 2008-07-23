require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$:.unshift "./lib"
require 'tap/constants'
require 'tap/patches/rake/testtask.rb'

#
# Gem specification
#

def gemspec
  data = File.read('tap.gemspec')
  spec = nil
  Thread.new { spec = eval("$SAFE = 3\n#{data}") }.join
  spec
end

Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.need_tar = true
end

desc 'Prints the gemspec manifest.'
task :print_manifest do
  # collect files from the gemspec, labeling 
  # with true or false corresponding to the
  # file existing or not
  files = gemspec.files.inject({}) do |files, file|
    files[File.expand_path(file)] = [File.exists?(file), file]
    files
  end
  
  # gather non-rdoc/pkg files for the project
  # and add to the files list if they are not
  # included already (marking by the absence
  # of a label)
  Dir.glob("**/*").each do |file|
    next if file =~ /^(rdoc|pkg)/ || File.directory?(file)
    
    path = File.expand_path(file)
    files[path] = ["", file] unless files.has_key?(path)
  end
  
  # sort and output the results
  files.values.sort_by {|exists, file| file }.each do |entry| 
    puts "%-5s : %s" % entry
  end
end

#
# Test tasks
#

desc 'Default: Run tests.'
task :default => :test

desc 'Run tests.'
Rake::TestTask.new(:test) do |t|
  t.test_files = if ENV['check']
    Dir.glob( File.join('test',  "**/*#{ENV['check']}*_check.rb") )
  else
    Dir.glob( File.join('test', ENV['pattern'] || '**/*_test.rb') ).delete_if do |filename|
      filename =~ /test\/check/ || filename =~ /test\/tap\/.*/
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
  spec = gemspec
  
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Tap (task application)'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include( spec.extra_rdoc_files )
  rdoc.rdoc_files.include( spec.files.select {|file| file =~ /^lib.*\.rb$/} )
  
  require 'tap/support/tdoc'
  rdoc.template = 'tap/support/tdoc/tdoc_html_template' 
  rdoc.options << '--fmt' << 'tdoc'
end

desc "Publish RDoc to RubyForge"
task :publish_rdoc => [:rdoc] do
  require 'yaml'
  
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml")))
  host = "#{config["username"]}@rubyforge.org"
  
  rsync_args = "-v -c -r"
  remote_dir = "/var/www/gforge-projects/tap/rdoc"
  local_dir = "rdoc"
 
  sh %{rsync #{rsync_args} #{local_dir}/ #{host}:#{remote_dir}}
end
