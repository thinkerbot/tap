require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/node'

class NodeTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :node
  
  def setup
    @node = Node.new
  end
    
  #
  # globalize test
  #
  
  def test_globalize_sets_input_and_output_to_nil
    node.input = :input
    node.output = :output
    
    node.globalize
    
    assert_equal nil, node.input
    assert_equal nil, node.output
  end
  
  #
  # global? test
  #

  def test_is_true_if_input_and_output_are_nil
    assert_equal nil, node.input
    assert_equal nil, node.output
    
    assert node.global?
    
    node.input = :input
    assert !node.global?
    
    node.input = nil
    node.output = :output
    assert !node.global?
  end
  
  #
  # round test
  #

  def test_round_returns_input_if_input_is_an_integer
    node.input = 1
    assert_equal 1, node.round  
  end
  
  def test_round_returns_nil_if_input_is_not_an_integer
    node.input = nil
    assert_equal nil, node.round
    
    node.input = :input
    assert_equal nil, node.round
  end
    
  #
  # round= test
  #
  
  def test_set_round_is_an_alias_for_set_input
    assert_equal nil, node.input
    node.round = :input
    assert_equal :input, node.input
  end
  
  #
  # natural_round test
  #
  
  def test_natural_round_documentation
    join1, join2 = Array.new(2) { Join.new }
    a = Node.new [], 0, join1
    b = Node.new [], 1, join1
    c = Node.new [], join1, join2
    d = Node.new [], join2
  
    assert_equal 0, d.natural_round
  
    join = Join.new
    a = Node.new [], nil, join
    b = Node.new [], 1, join
    c = Node.new [], 0, join
    d = Node.new [], join
  
    assert_equal 1, d.natural_round
  end
  
  def test_natural_round_returns_round_if_round_is_specified
    node.round = 1
    assert_equal 1, node.natural_round
    
    node.round = nil
    assert_equal nil, node.natural_round
  end
  
  def test_natural_round_returns_round_of_first_join_source_with_a_round
    join = Join.new
    
    n0 = Node.new [], 0, join
    n1 = Node.new [], 1, join
    n2 = Node.new [], join
    
    assert_equal [n0, n1], join.sources
    assert_equal join, n2.input
    assert_equal 0, n2.natural_round
    
    # now reversing sources
    join = Join.new
    
    n0 = Node.new [], 1, join
    n1 = Node.new [], 0, join
    n2 = Node.new [], join
    
    assert_equal 1, n2.natural_round
  end
  
  def test_natural_round_does_not_consider_globals_as_natural_rounds
    join = Join.new
    
    n0 = Node.new [], nil, join
    n1 = Node.new [], 1, join
    n2 = Node.new [], join
    
    assert_equal [n0, n1], join.sources
    assert_equal join, n2.input
    assert_equal 1, n2.natural_round
  end
  
  def test_natural_round_of_all_global_sources_is_nil
    join = Join.new
    
    n0 = Node.new [], nil, join
    n1 = Node.new [], nil, join
    n2 = Node.new [], join
    
    assert_equal [n0, n1], join.sources
    assert_equal join, n2.input
    assert_equal nil, n2.natural_round
  end
end