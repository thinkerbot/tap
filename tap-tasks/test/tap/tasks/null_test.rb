require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb') 
require 'tap/tasks/null'

class NullTest < Test::Unit::TestCase
  acts_as_tap_test 
  acts_as_shell_test(SH_TEST_OPTIONS)

  attr_reader :task
  
  def setup
    @task = Tap::Tasks::Null.new
    super
  end
  
  #
  # documentation test
  #

  def test_null_documentation
    sh_test %q{
% tap run -- load a --: null
}
  end
  
  #
  # null test
  #
  
  def test_null_returns_nil_for_all_inputs
    assert_equal nil, task.process()
    assert_equal nil, task.process(1)
    assert_equal nil, task.process(1, 2)
    assert_equal nil, task.process(1, 2) {}
  end
  
  def test_null_does_not_execute_app_defaullt_joins
    was_in_block = false
    app.on_complete { was_in_block = true }
    
    app.enq(task)
    app.run
    
    assert_equal false, was_in_block
    
    foil = app.node {}
    app.enq(foil)
    app.run
    
    assert_equal true, was_in_block
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_raises_error
    err = assert_raises(RuntimeError) { task.on_complete {} }
    assert_equal "cannot be participate in joins: #{task}", err.message
  end
end