require 'rake'

def gemspec(name)
  path = File.expand_path("#{name}.gemspec")
  eval(File.read(path), binding, path, 0)
end

def chdir(dir)
  pwd = Dir.pwd
  begin
    Dir.chdir(dir)
    yield
  ensure
    Dir.chdir(pwd)
  end
end

#
# Dependency tasks
#

desc 'Checkout submodules'
task :submodules do
  %w{. configurable}.each do |name|
    chdir(name) do
      output = `git submodule status 2>&1`

      if output =~ /^-/m
        puts "Missing submodules:\n#{output}"
        sh "git submodule init"
        sh "git submodule update"
        puts
      end
    end
  end
end

desc 'Bundle dependencies'
task :bundle => :submodules do
  output = `bundle check 2>&1`
  
  unless $?.to_i == 0
    puts output
    puts "bundle install 2>&1"
    system "bundle install 2>&1"
    puts
  end
end

#
# Test tasks
#

def libs(*groups)
  groups.collect! {|group| group.to_sym }
  
  require 'bundler'
  specs = Bundler.load.send(:specs_for, groups)
  specs.collect {|spec| spec.load_paths }.flatten.uniq
end

def load_paths(*groups)
  libs(*groups).collect {|lib| ['-I', lib] }.flatten
end

desc "Run tests"
task :test => :bundle do
  %w{
    tap
    tap-gen
    tap-tasks
    tap-test
    tap-server
  }.each do |name|
    chdir(name) do
      cmd = ['ruby', '-w', '-e', 'ARGV.each {|test| load test}']
      cmd.concat load_paths(name)
      cmd.concat Dir.glob("test/**/*_test.rb")
      sh(*cmd)
    end
  end
  
  puts %q{
All tests pass.  Try testing using tap itself:

  % ./tapexe test --all

}
end