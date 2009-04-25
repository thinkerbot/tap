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
      sh_match "% rap",
      /usage: rap/,
      /===  tap tasks ===/
      
      sh_match "% rap -T",
      /usage: rap/,
      /===  tap tasks ===/
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
      sh_match "% rap",
      /usage: rap/,
      /===  tap tasks ===/,
      /=== rake tasks ===/,
      /rake sample\s+# sample task/
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
  
  task :task_without_doc
  
  desc "desc"
  task :task_with_desc
end
}
    end
    
    method_root.chdir(:tmp) do
      sh_match "% rap",
      /usage: rap/,
      /tmp:/,
      /task_with_doc\s+# task summary/,
      /task_with_desc\s+# desc/
      
      sh_match "% rap task_with_doc --help",
      /RapTest::TaskWithDoc -- task summary/,
      /long description/,
      /usage: rap rap_test\/task_with_doc/
      
      sh_match "% rap task_without_doc --help",
      /RapTest::TaskWithoutDoc/,
      /usage: rap rap_test\/task_without_doc/
    
      sh_match "% rap task_with_desc --help",
      /RapTest::TaskWithDesc -- desc/,
      /usage: rap rap_test\/task_with_desc/
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
      sh_match "% rap",
      /tmp:/,
      /task\s+# first desc/,
      /sample\/task\s+# second desc/
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
      sh_match "% rap task_without_args --help",
      /usage: rap rap_test\/task_without_args\s*$/
      
      sh_match "% rap task_with_args --help",
      /usage: rap rap_test\/task_with_args A B\s*$/
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