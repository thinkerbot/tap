require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/tasks/argv'

class ArgvTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  
  #
  # process test
  #
  
  def test_process_returns_argv
    assert_equal ARGV.object_id, Argv.new.process.object_id
  end
end