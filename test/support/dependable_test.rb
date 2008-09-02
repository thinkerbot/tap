require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/dependable'

class DependableTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :m
  
  def setup
    @m = Module.new
    @m.extend Dependable
  end
  
  #
  # extend test
  #
  
  def test_dependable_intializes_registry_and_results_on_extend
    m = Module.new
    m.extend Dependable
    
    assert_equal [], m.registry
    assert_equal [], m.results
  end
  
  #
  # clear_dependencies test
  #
  
  def test_clear_dependencies_resets_the_registry_and_results
    m.registry << :a
    m.results << :b
    
    assert_not_equal [], m.registry
    assert_not_equal [], m.results
    
    m.clear_dependencies
    
    assert_equal [], m.registry
    assert_equal [], m.results
  end
  
  #
  # index test
  #
  
  def test_index_returns_the_index_of_the_instance_argv_pair_in_self
    m.registry << [:a, [1,2,3]]
    m.registry << [:b, [4,5]]
    m.registry << [:c, []]
    
    assert_equal 0, m.index(:a, [1,2,3])
    assert_equal 2, m.index(:c, [])
    assert_equal 2, m.index(:c)
  end
  
  def test_index_returns_nil_if_the_pair_is_not_registered
    assert_nil m.index(:a, [])
    assert_nil m.index(:a)
  end
  
  #
  # register test
  #
  
  def test_register_adds_the_instance_argv_pair_to_registry
    assert_equal [], m.registry

    m.register(:a, [1,2,3])
    m.register(:a, [4,5])
    m.register(:b, [4,5])
    m.register(:c)
    
    assert_equal [
      [:a, [1,2,3]], 
      [:a, [4,5]], 
      [:b, [4,5]], 
      [:c, []]
    ], m.registry
  end
  
  def test_register_does_not_duplicate_existing_instance_argv_pairs_in_registry
    m.registry << [:a, [1,2,3]]
    m.registry << [:b, [4,5]]
    m.registry << [:c, []]
    
    m.register(:a, [1,2,3])
    m.register(:c, [])
    m.register(:c)
    
    assert_equal [
      [:a, [1,2,3]],
      [:b, [4,5]],
      [:c, []]
    ], m.registry
  end
  
  def test_register_returns_the_index_of_the_instance_argv_pair_in_self
    m.registry << [:a, [1,2,3]]
    m.registry << [:b, [4,5]]
    m.registry << [:c, []]
    
    assert_equal 0, m.register(:a, [1,2,3])
    assert_equal 2, m.register(:c, [])
    
    assert_equal 3, m.register(:d)
    assert_equal 4, m.register(:e, [1,2,3])
    assert_equal 3, m.register(:d)
  end
  
  #
  # resolve test
  #
  
  class ExecutableMock
    def _execute(*args)
      args << object_id
      args
    end
  end
  
  def test_resolve_resolves_instance_argv_pairs_at_the_specified_indicies
    a = ExecutableMock.new
    c = ExecutableMock.new
    
    m.registry << [a, [1,2,3]]
    m.registry << [:b, []]
    m.registry << [c, []]
    
    m.resolve([0,2])
    
    assert m.resolved?(0)
    assert m.resolved?(2)
    
    assert_equal [[1,2,3, a.object_id], nil, [c.object_id]], m.results
  end
  
  def test_resolve_does_not_re_resolve_resolved_pairs
    a = ExecutableMock.new
    m.registry << [a, [1,2,3]]

    m.resolve([0])
    assert_equal [[1,2,3, a.object_id]], m.results
    
    m.registry[0] = [a, []]
    
    m.resolve([0])
    assert_equal [[1,2,3, a.object_id]], m.results
    
    m.reset([0])
    m.resolve([0])
    assert_equal [[a.object_id]], m.results
  end
  
  #
  # resolved? test
  #
  
  def test_resolved_is_true_if_the_results_at_the_index_are_non_nil
    m.results.concat([:a, nil, :c])
    
    assert m.resolved?(0)
    assert m.resolved?(2)
    assert m.resolved?(-1)
    
    assert !m.resolved?(1)
    assert !m.resolved?(100)
  end
  
  #
  # reset test
  #

  def test_reset_resets_the_results_at_the_specified_indicies_to_nil
    m.results.concat([:a, :b, :c])
    m.reset([0,2])
    assert_equal [nil, :b, nil], m.results
  end
  
  def test_reset_returns_self
    assert_equal m, m.reset([])
  end
end