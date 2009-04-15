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
  # intern tests
  #
  
  def test_intern_makes_dependency_from_block
    m = Dependency.intern { "result" }
    assert m.kind_of?(Dependency)
    assert_equal nil, m.result
    assert_equal "result", m.call
    assert_equal "result", m.result
  end
  
  #
  # extend tests
  #
  
  def test_extend_sets_result_to_nil
    assert_equal nil, m.result
  end
  
  #
  # dependency? tests
  #
  
  def test_dependency_returns_true_if_obj_satisifies_the_dependency_API
    m = Dependency.intern {}
    assert Dependency.dependency?(m)
    
    m = Object.new
    assert !Dependency.dependency?(m)
    
    m.extend(Module.new {def call; end})
    assert !Dependency.dependency?(m)
    
    m.extend(Module.new {def result; end})
    assert !Dependency.dependency?(m)
    
    m.extend(Module.new {def reset; end})
    assert Dependency.dependency?(m)
  end
  
  #
  # register test
  #
  
  class MockDependency
    attr_reader :call, :result, :reset
  end
  
  def test_register_extends_the_input_object_if_it_does_not_satisfy_the_dependency_API
    m = Object.new
    Dependency.register(m)
    assert m.kind_of?(Dependency)
    
    m = MockDependency.new
    Dependency.register(m)
    assert !m.kind_of?(Dependency)
  end
  
  def test_register_returns_obj
    m = Dependency.intern {}
    assert_equal m, Dependency.register(m)
    
    m = Object.new
    assert_equal m, Dependency.register(m)
  end
  
  #
  # call test
  #
  
  def test_call_runs_only_once
    assert_equal 0, n
    
    m.call
    assert_equal 1, n
    
    m.call
    assert_equal 1, n
  end
  
  def test_call_runs_again_after_reset
    assert_equal 0, n
    
    m.call
    assert_equal 1, n
    
    m.reset
    m.call
    assert_equal 2, n
  end

  def test_call_sets_result
    assert_equal nil, m.result
    m.call
    assert_equal "result", m.result
  end
  
  #
  # reset test
  #
  
  def test_reset_sets_result_to_nil
    m.call
    assert_equal "result", m.result
    m.reset
    assert_equal nil, m.result
  end
end