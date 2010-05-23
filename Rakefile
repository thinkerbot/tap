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

desc "Run tests"
task :test => :bundle do
  require 'bundler'
  bundler = Bundler.load
  
  modules = ENV['MODULE'] ||= %q{
    tap
    tap-gen
    tap-tasks
    tap-test
  }
  
  modules.split.each do |name|
    chdir(name) do
      cmd = ['ruby', '-w', '-e', 'ARGV.each {|test| load test}']
      cmd.concat bundler.load_paths(name)
      cmd.concat Dir.glob("test/**/*_test.rb")
      sh(*cmd)
    end
  end
  
  puts %q{
All tests pass.  Try testing using tap itself:

  % ./tapexe test --all

}
end