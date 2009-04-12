require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/dependency'

class DependencyTest < Test::Unit::TestCase
  Dependency = Tap::App::Dependency
  
  attr_accessor :m, :n
  
  def setup
    @n = 0
    @m = lambda do
      @n += 1
      "result"
    end.extend Dependency
  end
  
  #
  # extend tests
  #
  
  def test_call_sets__result
    assert_equal nil, m._result
    m.call
    assert_equal "result", m._result
  end
  
  #
  # call test
  #
  
  def test_call_conditionally_runs_only_when_not_resolved
    assert !m.resolved?
    assert_equal 0, n
    
    m.call
    assert_equal 1, n
    
    assert m.resolved?

    m.call
    assert_equal 1, n
    
    m._result = nil
    assert !m.resolved?
    
    m.call
    assert_equal 2, n
  end
  
  #
  # resolve test
  #
  
  def test_resolve_is_an_alias_for_call
    assert !m.resolved?

    m.resolve
    
    assert m.resolved?
    assert_equal "result", m._result
    assert_equal 1, n
  end
  
  #
  # resolved? test
  #
  
  def test_resolved_is_true_if__result_is_non_nil
    assert_equal nil, m._result
    assert !m.resolved?
    
    m._result = "result"
    assert m.resolved?
  end
  
  #
  # reset test
  #
  
  def test_reset_sets__result_to_nil
    m._result = "result"
    assert_equal "result", m._result
    m.reset
    assert_equal nil, m._result
  end
end