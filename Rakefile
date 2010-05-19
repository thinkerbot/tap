require 'rake'

def gemspec(name)
  path = File.expand_path("#{name}.gemspec")
  eval(File.read(path), binding, path, 0)
end

#
# Dependency tasks
#

desc 'Checkout submodules'
task :submodules do
  output = `git submodule status 2>&1`

  if output =~ /^-/m
    puts "Missing submodules:\n#{output}"
    sh "git submodule init"
    sh "git submodule update"
    puts
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
  %w{
    tap
    tap-gen
    tap-tasks
    tap-test
  }.each do |name|
    pwd = Dir.pwd
    begin
      Dir.chdir(name)
    
      libs = ['lib']
      unless ENV['gems']
        libs << '../configurable/lib'
        libs << '../lazydoc/lib'
      end
  
      gemspec(name).dependencies.each do |dep|
        libs << File.join('..', dep.name, 'lib')
      end

      cmd = ['ruby', '-w', '-e', 'ARGV.each {|test| load test}']
      libs.uniq.each {|lib| cmd.concat ['-I', lib] }
      cmd.concat Dir.glob("test/**/*_test.rb")
      sh(*cmd)
    ensure
      Dir.chdir(pwd)
    end
  end
  
  puts %q{
All tests pass.  Try testing using tap itself:

  % ./tapexe test --all

}
end