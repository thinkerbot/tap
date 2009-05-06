require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/tasks/file_task/shell_utils'

class ShellUtilsTest < Test::Unit::TestCase
  include Tap::Tasks::FileTask::ShellUtils

  #
  # capture_sh test
  #
  
  def test_capture_sh
    assert_equal "hello\n", capture_sh('echo hello')
  end
  
  def test_capture_sh_with_block
    was_in_block = false
    result = capture_sh('echo hello') do |ok, status|
      assert ok
      was_in_block = true
    end
    assert_equal "hello\n", result
    assert was_in_block
  end
end