require File.join(File.dirname(__FILE__), '../rap_test_helper')

class RapTest < Test::Unit::TestCase
  acts_as_file_test
  acts_as_shell_test
  
  RAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
  LOAD_PATHS = [
    "-I'#{RAP_ROOT}/../configurable/lib'",
    "-I'#{RAP_ROOT}/../lazydoc/lib'",
    "-I'#{RAP_ROOT}/../tap/lib'"
  ]
  
  CMD_PATTERN = "% rap"
  CMD = (["TAP_GEMS= ruby"] + LOAD_PATHS + ["'#{RAP_ROOT}/bin/rap'"]).join(" ")

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
  # ::desc task summary
  # long description
  task :task_with_doc
  
  # ::desc
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
        assert output =~ /usage: rap rap_test\/task_with_doc/
      end
      
      sh_test "% rap task_with_empty_desc --help" do |output|
        assert output =~ /RapTest::TaskWithEmptyDesc/
        assert output !~ /::desc/
      end
      
      sh_test "% rap task_without_doc --help" do |output|
        assert output =~ /RapTest::TaskWithoutDoc/
        assert output =~ /usage: rap rap_test\/task_without_doc/
      end
    
      sh_test "% rap task_with_desc --help" do |output|
        assert output =~ /RapTest::TaskWithDesc -- desc/
        assert output =~ /usage: rap rap_test\/task_with_desc/
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
        assert output =~ /usage: rap rap_test\/task_without_args\s*$/
      end
      
      sh_test "% rap task_with_args --help" do |output|
        assert output =~ /usage: rap rap_test\/task_with_args A B\s*$/
      end
    end
  end
  
  def test_rap_runs_tasks_from_rapfile
    method_root.prepare(:tmp, 'Rapfile') {|file| file << "Rap.task(:echo) { puts 'echo!' }"}
    method_root.chdir(:tmp) do
      sh_test %q{
% rap echo
echo!
}
    end
  end
end