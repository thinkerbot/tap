require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'

class TaskBaseTest < Test::Unit::TestCase
  include Tap

  attr_accessor :t
  
  def setup
    super
    @t = ObjectWithExecute.new
    Tap::Task::Base.initialize(@t, :execute)
  end
  
  #
  # initialize tests
  #
  
  def test_initialize
    assert_equal [t], t.batch
    assert_equal Tap::App.instance, t.app
  end
  
end
