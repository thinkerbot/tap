require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/dependency'

class DependencyTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :m
  
  class SimpleExecutable
    attr_reader :trace
    
    def initialize(trace=[])
      @trace = trace
      Tap::Support::Executable.initialize(self, :run)
    end
    
    def run
      @trace << self
      "result"
    end
  end
  
  def setup
    @m = SimpleExecutable.new.extend Dependency
  end
  
  #
  # extend tests
  #
  
  def test_extend_sets_on_complete_block_to_set__result
    m = SimpleExecutable.new
    assert m.on_complete_block == nil
    m.extend Dependency
    assert m.on_complete_block != nil
    
    assert_equal nil, m._result
    m._execute
    assert_equal "result", m._result._current
  end
  
  #
  # _execute test
  #
  
  def test__execute_conditionally_runs_only_when_not_resolved
    assert !m.resolved?
    assert_equal [], m.trace
    
    m._execute
    assert_equal [m], m.trace
    
    assert m.resolved?

    m._execute
    assert_equal [m], m.trace
    
    m._result = nil
    assert !m.resolved?
    
    m._execute
    assert_equal [m, m], m.trace
  end
  
  #
  # resolve test
  #
  
  def test_resolve_is_an_alias_for__execute
    assert !m.resolved?

    m.resolve
    
    assert m.resolved?
    assert_equal "result", m._result._current
    assert_equal [m], m.trace
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