require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/node'

class NodeTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :node
  
  def setup
    @node = Node.new
  end
  
  #
  # Node.natural_round test
  #
  
  def test_natural_round_documentation
    # (3)-o-[A]-o-[C]-o-[D]
    #           |
    # (2)-o-[B]-o
  
    join1, join2 = Array.new(2) { [:join, [], []] }
    a = Node.new [], 3, join1
    b = Node.new [], 2, join1
    c = Node.new [], join1, join2
    d = Node.new [], join2
  
    assert_equal 2, Node.natural_round([d])
  
    # ( )-o-[E]-o
    #           |
    # (1)-o-[F]-o
    #           |
    # (2)-o-[G]-o-[H]
  
    join = [:join, [], []]
    e = Node.new [], nil, join
    f = Node.new [], 1, join
    g = Node.new [], 2, join
    h = Node.new [], join
  
    assert_equal 1, Node.natural_round([d, h])
  end
  
  def test_natural_round_returns_lowest_round_of_input_nodes
    a = Node.new [], 2
    b = Node.new [], 1
    c = Node.new [], 5
    d = Node.new [], nil
    
    assert_equal 1, Node.natural_round([a,b,c,d])
  end
  
  def test_natural_round_returns_zero_if_all_nodes_are_global
    a = Node.new [], nil
    b = Node.new [], nil
    
    assert_equal 0, Node.natural_round([a,b])
  end
  
  def test_natural_round_returns_lowest_round_of_join_parents
    a = Node.new [], 2
    b = Node.new [], 1
    c = Node.new [], 5
    d = Node.new [], nil
    e = Node.new [], [:join, [a,b,c,d], []]
    
    assert_equal 1, Node.natural_round([e])
  end
  
  def test_natural_round_recurses_for_join_parents
    a = Node.new [], 2
    b = Node.new [], 1
    c = Node.new [], [:join, [a,b], []]
    d = Node.new [], nil
    e = Node.new [], [:join, [c,d], []]
    
    assert_equal 1, Node.natural_round([e])
  end
  
  def test_natural_round_does_not_infinitely_loop
    join = [:join, [], []]
    a = Node.new
    a.input = join
    a.output = join
    
    assert_equal 0, Node.natural_round([a])
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    node = Node.new
    assert_equal [], node.argv
    assert_equal 0, node.input
    assert_equal nil, node.output
  end
  
  def test_initialize_with_input_join_adds_self_to_input_join_outputs
    join = [:join, [], []]
    node = Node.new [], join
    
    assert_equal [:join, [], [node]], join
  end
  
  def test_initialize_with_output_join_adds_self_to_output_join_inputs
    join = [:join, [], []]
    node = Node.new [], nil, join
    
    assert_equal [:join, [node], []], join
  end
  
  #
  # parents test
  #
  
  def test_parents_returns_array_of_input_join_inputs
    join = [:join, [:a, :b, :c], []]
    node = Node.new [], join
    
    assert_equal [:a, :b, :c], node.parents
  end
  
  def test_parents_is_empty_array_if_input_is_not_a_join
    assert_equal 0, node.input
    assert_equal [], node.parents
  end
  
  #
  # children test
  #
  
  def test_children_returns_array_of_output_join_outputs
    join = [:join, [], [:a, :b, :c]]
    node = Node.new [], nil, join
    
    assert_equal [:a, :b, :c], node.children
  end
  
  def test_children_is_empty_array_if_output_is_not_a_join
    assert_equal nil, node.output
    assert_equal [], node.children
  end
  
  #
  # input= test
  #
  
  def test_input_set_sets_input
    node.input = :input
    assert_equal :input, node.input
  end
  
  def test_input_set_adds_self_to_join_outputs
    join = [:join, [], []]
    
    assert_equal [:join, [], []], join
    node.input = join
    assert_equal [:join, [], [node]], join
  end
  
  def test_input_set_removes_self_from_current_input_join_outputs
    join = [:join, [], []]
    node = Node.new [], join
    
    assert_equal [:join, [], [node]], join
    node.input = nil
    assert_equal [:join, [], []], join
  end
  
  #
  # output= test
  #
  
  def test_output_set_adds_self_to_join_inputs
    join = [:join, [], []]
    
    assert_equal [:join, [], []], join
    node.output = join
    assert_equal [:join, [node], []], join
  end
  
  def test_output_set_removes_self_from_current_output_join_inputs
    join = [:join, [], []]
    node = Node.new [], nil, join
    
    assert_equal [:join, [node], []], join
    node.output = nil
    assert_equal [:join, [], []], join
  end
  
  def test_if_resetting_output_produces_an_orphan_join_then_output_sets_children_input_to_natural_round
    join1 = [:join, [], []]
    join2 = [:join, [], []]
    
    a = Node.new [], 1, join1
    b = Node.new [], 2, join1
    c = Node.new [], join1, join2
    d = Node.new [], join2
    e = Node.new [], join2
    
    assert_equal 1, c.natural_round
    assert_equal [d,e], c.children
    assert_equal nil, d.round
    assert_equal nil, e.round
    
    c.output = nil
    
    assert_equal 1, d.round
    assert_equal 1, e.round
  end
  
  #
  # make_prerequisite test
  #
  
  def test_make_prerequisite_sets_input_to_nil
    assert_equal 0, node.input
    node.make_prerequisite
    assert_equal nil, node.input
  end
  
  #
  # prerequisite? test
  #
  
  def test_is_true_if_input_is_nil
    node = Node.new [], nil, nil
    
    assert_equal nil, node.input
    assert node.prerequisite?
    
    node.input = :input
    assert !node.prerequisite?
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
    assert_equal 0, node.input
    node.round = 1
    assert_equal 1, node.input
  end
end