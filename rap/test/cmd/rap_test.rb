require File.join(File.dirname(__FILE__), '../rap_test_helper')

class RapTest < Test::Unit::TestCase
  rap_root = File.expand_path(File.dirname(__FILE__) + "/../..")
  load_paths = [
    "-I'#{rap_root}/../configurable/lib'",
    "-I'#{rap_root}/../lazydoc/lib'",
    "-I'#{rap_root}/../tap/lib'"
  ]
  
  acts_as_file_test
  acts_as_shell_test(
    :cmd_pattern => "% rap",
    :cmd => (["ruby"] + load_paths + ["'#{rap_root}/bin/rap'"]).join(" "),
    :env => {'TAP_GEMS' => ''}
  )

  def test_rap_help
    method_root.chdir(:tmp, true) do
      sh_test "% rap" do |output|
        assert output =~ /usage: rap/
        assert output =~ /===  tap tasks ===/
      end
      
      sh_test "% rap -T" do |output|
        assert output =~ /usage: rap/
        assert output =~ /===  tap tasks ===/
      end
    end
  end
  
  def test_rap_help_lists_rake_tasks
    method_root.prepare(:tmp, 'Rakefile') do |file|
      file << %q{
desc "sample task"
task :sample
}
    end
        
    method_root.chdir(:tmp, true) do
      sh_test "% rap" do |output|
        assert output =~ /usage: rap/
        assert output =~ /===  tap tasks ===/
        assert output =~ /=== rake tasks ===/
        assert output =~ /rake sample\s+# sample task/
      end
    end
  end
  
  def test_rap_help_with_declarations
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
include Rap::Declarations
  
namespace :rap_test do
  # :: task summary
  # long description
  task :task_with_doc
  
  # ::
  task :task_with_empty_desc
  
  task :task_without_doc
  
  desc "desc"
  task :task_with_desc
end
}
    end
    
    method_root.chdir(:tmp) do
      sh_test "% rap" do |output|
        assert output =~ /usage: rap/, output
        assert output =~ /tmp:/, output
        assert output =~ /task_with_doc\s+# task summary/, output
        assert output =~ /task_with_empty_desc\s+# /, output
        assert output =~ /task_with_desc\s+# desc/, output
        assert output !~ /task_without_doc/, output
      end
      
      sh_test "% rap task_with_doc --help" do |output|
        assert output =~ /RapTest::TaskWithDoc -- task summary/
        assert output =~ /long description/
        assert output =~ /rap_test\/task_with_doc/
      end
      
      sh_test "% rap task_with_empty_desc --help" do |output|
        assert output =~ /RapTest::TaskWithEmptyDesc/
        assert output !~ /::desc/
      end
      
      sh_test "% rap task_without_doc --help" do |output|
        assert output =~ /RapTest::TaskWithoutDoc/
        assert output =~ /rap_test\/task_without_doc/
      end
    
      sh_test "% rap task_with_desc --help" do |output|
        assert output =~ /RapTest::TaskWithDesc -- desc/
        assert output =~ /rap_test\/task_with_desc/
      end
    end
  end
  
  def test_rap_help_with_duplicate_nested_declarations
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
include Rap::Declarations

desc "first desc"
task :task

namespace :sample do
  desc "first desc"
  task :task

  desc "second desc"
  task :task
end
}
    end
    
    method_root.chdir(:tmp) do
      sh_test "% rap" do |output|
        assert output =~ /tmp:/
        assert output =~ /task\s+# first desc/
        assert output =~ /sample\/task\s+# second desc/
      end
    end
  end
      
  def test_rap_help_for_tasks_with_args
    method_root.prepare(:tmp, 'rapfile') do |file|
      file << %q{
include Rap::Declarations
namespace :RapTest do

  task(:task_without_args)
  task(:task_with_args, :a, :b)
end
}
    end

    method_root.chdir(:tmp) do
      sh_test "% rap task_without_args --help" do |output|
        assert output =~ /rap_test\/task_without_args\s*$/
      end
      
      sh_test "% rap task_with_args --help" do |output|
        assert output =~ /rap_test\/task_with_args A B\s*$/
      end
    end
  end
  
  def test_rap_runs_rap_tasks_from_rapfile
    method_root.prepare(:tmp, 'Rapfile') {|file| file << "Rap.task(:echo) { puts 'echo!' }"}
    method_root.chdir(:tmp) do
      sh_test %q{
% rap echo
echo!
}
    end
  end
  
  def test_rap_runs_tap_tasks_from_rapfile
    method_root.prepare(:tmp, 'Rapfile') do |file| 
      file << %Q{
# Echo::task
class Echo < Tap::Task
  def process
    puts "echo!"
  end
end
}

    end
    method_root.chdir(:tmp) do
      sh_test %q{
% rap echo
echo!
}
    end
  end
  
  #
  # rap and rake
  #
  

  def test_rap_runs_rake_tasks
    rakefile = method_root.prepare(:tmp, 'Rakefile') do |file| 
      file << %q{
require 'rake'
task(:a) { puts 'A' }
task(:b => :a) { puts 'B' }
task(:c, :str) {|task, args| puts "#{args.str.upcase}" }

namespace :ns do
  task(:a) { puts 'nsA' }
  task(:b => :a) { puts 'nsB' }
  task(:c, :str) {|task, args| puts "ns#{args.str.upcase}" }
end
}
    end
    
    method_root.chdir(:tmp) do
      sh_test %Q{
% rap a
(in #{File.dirname(rakefile)})
A
}
      sh_test %Q{
% rap a --silent
A
}
      sh_test %Q{
% rap b --silent
A
B
}      
      sh_test %Q{
% rap c[arg] --silent
ARG
}
      sh_test %Q{
% rap ns:a --silent
nsA
}
      sh_test %Q{
% rap ns:c[arg] ns:b ns:a b --silent
nsARG
nsA
nsB
A
B
}
    end
  end
  
  def test_rap_behaves_much_as_rake
    # differences:
    # * namespace dependencies are resolved from base (:b => 'ns/a')
    # * args not specified in []
    # * tasks separated by '--'
    #
    rakefile = method_root.prepare(:tmp, 'Rapfile') do |file| 
      file << %q{
include Rap::Declarations

task(:a) { puts 'A' }
task(:b => :a) { puts 'B' }
task(:c, :str) {|task, args| puts "#{args.str.upcase}" }

namespace :ns do
  task(:a) { puts 'nsA' }
  task(:b => 'ns/a') { puts 'nsB' }
  task(:c, :str) {|task, args| puts "ns#{args.str.upcase}" }
end
}
    end

    method_root.chdir(:tmp) do
      sh_test %Q{
% rap a
A
}

      sh_test %Q{
% rap b
A
B
}      
      sh_test %Q{
% rap c arg 
ARG
}
      sh_test %Q{
% rap ns/a
nsA
}
      sh_test %Q{
% rap ns/c arg -- ns/b -- ns/a -- b
nsARG
nsA
nsB
A
B
}
    end
  end
end