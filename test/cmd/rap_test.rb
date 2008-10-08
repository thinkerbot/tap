require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test/script_test'

class RapTest < Test::Unit::TestCase
  acts_as_script_test

  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/rap")

  def setup
    super
    make_test_directories
    FileUtils.touch(method_root.filepath(:output, 'tap.yml'))
    FileUtils.touch(method_root.filepath(:output, 'Rakefile'))
  end

  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end

  def test_rap_help_with_no_declarations
    script_test(method_root[:output]) do |cmd|
      cmd.check "Prints help and summary for rap", %Q{
% #{cmd}
usage: rap taskname {options} [args]

===  tap tasks ===
  dump        # the default dump task
  load        # the default load task
  rake        # run rake tasks

=== rake tasks ===
:...:
% #{cmd} -T
usage: rap taskname {options} [args]

===  tap tasks ===
  dump        # the default dump task
  load        # the default load task
  rake        # run rake tasks

=== rake tasks ===
:...:
}
    end
  end
  
  def test_rap_help_with_declarations
    File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations
  
  # ::desc task summary
  # long description
  task :task_with_doc
  
  task :task_without_doc
  
  desc "desc"
  task :task_with_desc
end
}
    end
    
    script_test(method_root[:output]) do |cmd|
      cmd.check "Prints summary of declarations", %Q{
% #{cmd}
usage: rap taskname {options} [args]

===  tap tasks ===
output:
  task_with_doc     # task summary
  task_with_desc    # desc
tap:
  dump              # the default dump task
  load              # the default load task
  rake              # run rake tasks

=== rake tasks ===
:...:
}

      cmd.check "Prints help for declaration", %Q{
% #{cmd} task_with_doc --help
RapTest::TaskWithDoc -- task summary
--------------------------------------------------------------------------------
  long description
--------------------------------------------------------------------------------
usage: tap run -- rap_test/task_with_doc 
:...:
% #{cmd} task_without_doc --help
RapTest::TaskWithoutDoc

usage: tap run -- rap_test/task_without_doc 
:...:
% #{cmd} task_with_desc --help
RapTest::TaskWithDesc -- desc

usage: tap run -- rap_test/task_with_desc 
:...:}
    end
  end
  
  def test_rap_help_for_tasks_with_args
    File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations

  task(:task_without_args) {}
  task(:task_with_args) {|task, args|}
end
}
    end

    script_test(method_root[:output]) do |cmd|
      cmd.check "Prints help for declaration", %Q{
% #{cmd} task_without_args --help
:...:
usage: tap run -- rap_test/task_without_args 
:...:
% #{cmd} task_with_args --help
:...:
usage: tap run -- rap_test/task_with_args 
:...:
}
    end
  end
  
  def test_rap_help_for_tasks_with_arg_names
    File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations
  
  task(:task_without_args, :a, :b) {}
  task(:task_with_args, :a, :b) {|task, one, two|}
end
}
    end

    script_test(method_root[:output]) do |cmd|
      cmd.check "Prints help for declaration", %Q{
% #{cmd} task_without_args --help
:...:
usage: tap run -- rap_test/task_without_args a b
:...:
% #{cmd} task_with_args --help
:...:
usage: tap run -- rap_test/task_with_args a b
:...:
}
    end
  end
end