require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$:.unshift File.expand_path("#{File.dirname(__FILE__)}/lib")
require 'tap/constants'
require 'tap/patches/rake/testtask.rb'

desc "Compiles tap into a single rb script"
task :compile do
  # interesting proposal -- much, much quicker loading on 
  # windows where reading files is apparently quite slow.
  #
  # Notes:
  # - Task files should not be included since they may contain
  #   manifest information that implicitly uses the path name.
  # - Autoloaded files should not be included either (and in 
  #   some cases maybe a require should be turned into an 
  #   autoload?)
  #
  @@sources = {}
  def require(file)
    result = super
    
    tap_file = "#{File.dirname(__FILE__)}/lib/#{file}.rb"
    return result unless File.exists?(tap_file)
    
    content = File.read(tap_file)
    content.gsub!(/^require\s+['"](.*)['"]$/) do |match|
      @@sources.has_key?($1) ? @@sources[$1] : match
    end
    @@sources[file] = content
    
    result
  end
  
  require 'tap'
  File.open("taq.rb", "w") do |target|
    target << @@sources['tap'].gsub(/\r?\n^\s*\#.*$/, "")
  end
end

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
    puts "%-5s %s" % entry
  end
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
  
  files = spec.files.select {|file| file =~ /^lib.*\.rb$/}
  files.delete_if {|file| file =~ /generators\/.*\/templates/ }
  rdoc.rdoc_files.include( files )
  
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

desc "Publish Website to RubyForge"
task :publish_website do
  require 'yaml'
  
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml")))
  host = "#{config["username"]}@rubyforge.org"
  
  rsync_args = "-v -c -r"
  remote_dir = "/var/www/gforge-projects/tap"
  local_dir = "pkg/website"
 
  sh %{rsync #{rsync_args} #{local_dir}/ #{host}:#{remote_dir}}
end


#
# Test tasks
#

desc 'Default: Run tests.'
task :default => :test

desc 'Run tests.'
Rake::TestTask.new(:test) do |t|
  t.test_files = Dir.glob( File.join('test', ENV['pattern'] || '**/*_test.rb') ).delete_if do |filename|
    filename =~ /test\/check/ || filename =~ /test\/cmd\/.*\//
  end
  
  t.verbose = true
  t.warning = true
end
