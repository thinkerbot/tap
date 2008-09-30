require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test/script_test'

class RapTest < Test::Unit::TestCase
  acts_as_script_test :directories => {}

  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/rap")

  def setup
    super
    FileUtils.mkdir_p(method_root.root)
    FileUtils.touch(method_root.filepath(:root, 'tap.yml'))
    FileUtils.touch(method_root.filepath(:root, 'Rakefile'))
  end

  def teardown
    FileUtils.rm(method_root.filepath(:root, 'tap.yml'))
    FileUtils.rm(method_root.filepath(:root, 'Rakefile'))
    super
  end

  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end

  def test_rap_help_with_no_declarations
    script_test do |cmd|
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
  
  def test_rap_help_with_only_declarations
    File.open(method_root.filepath(:root, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations
  
  # ::desc tasc summary
  # long description
  tasc :tasc_with_doc
  
  tasc :tasc_without_doc
  
  # ::desc task summary
  # long description
  task :task_with_doc
  
  task :task_without_doc
end
}
    end
    
    script_test do |cmd|
      cmd.check "Prints summary of declarations", %Q{
% #{cmd}
usage: rap taskname {options} [args]

===  tap tasks ===
test_rap_help_with_only_declarations:
  tasc_with_doc     # tasc summary
  tasc_without_doc
  task_with_doc     # task summary
  task_without_doc
tap:
  dump              # the default dump task
  load              # the default load task
  rake              # run rake tasks

=== rake tasks ===
:...:
}

      cmd.check "Prints help for declaration", %Q{
% #{cmd} tasc_with_doc --help
RapTest::TascWithDoc -- tasc summary
--------------------------------------------------------------------------------
  long description
--------------------------------------------------------------------------------
usage: tap run -- rap_test/tasc_with_doc 
:...:
% #{cmd} tasc_without_doc --help
RapTest::TascWithoutDoc

usage: tap run -- rap_test/tasc_without_doc 
:...:
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
}
    end
  end
  
  def test_rap_help_for_tasks_with_args
    File.open(method_root.filepath(:root, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations

  tasc(:tasc_with_no_block)
  tasc(:tasc_with_no_args) {}
  tasc(:tasc_with_arg) {|arg|}
  tasc(:tasc_with_args) {|one, two|}
  tasc(:tasc_with_splat) {|arg, *splat|}
  
  task(:task_without_args) {}
  task(:task_with_args) {|task, args|}
end
}
    end

    script_test do |cmd|
      cmd.check "Prints help for declaration", %Q{
% #{cmd} tasc_with_no_block --help
:...:
usage: tap run -- rap_test/tasc_with_no_block 
:...:
% #{cmd} tasc_with_no_args --help
:...:
usage: tap run -- rap_test/tasc_with_no_args INPUTS...
:...:
% #{cmd} tasc_with_arg --help
:...:
usage: tap run -- rap_test/tasc_with_arg INPUT
:...:
% #{cmd} tasc_with_args --help
:...:
usage: tap run -- rap_test/tasc_with_args INPUT INPUT
:...:
% #{cmd} tasc_with_splat --help
:...:
usage: tap run -- rap_test/tasc_with_splat INPUT INPUTS...
:...:
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
    File.open(method_root.filepath(:root, 'Tapfile'), 'w') do |file|
      file << %q{
module RapTest
  extend Tap::Declarations

  tasc(:tasc_with_arg, :a) {|arg|}
  tasc(:tasc_with_args, :a, :b) {|one, two|}
  tasc(:tasc_with_splat, :a, 'b...') {|arg, *splat|}

  task(:task_without_args, :a, :b) {}
  task(:task_with_args, :a, :b) {|task, one, two|}
end
}
    end

    script_test do |cmd|
      cmd.check "Prints help for declaration", %Q{
% #{cmd} tasc_with_arg --help
:...:
usage: tap run -- rap_test/tasc_with_arg a
:...:
% #{cmd} tasc_with_args --help
:...:
usage: tap run -- rap_test/tasc_with_args a b
:...:
% #{cmd} tasc_with_splat --help
:...:
usage: tap run -- rap_test/tasc_with_splat a b...
:...:
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