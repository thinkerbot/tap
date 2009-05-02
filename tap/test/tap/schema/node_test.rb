require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema/node'

class SchemaNodeTest < Test::Unit::TestCase
  Node = Tap::Schema::Node
  Join = Tap::Schema::Join
  
  attr_reader :node
  
  def setup
    @node = Node.new
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    node = Node.new
    assert_equal nil, node.metadata
    assert_equal nil, node.input
    assert_equal nil, node.output
  end
  
  def test_initialize_with_input_join_adds_self_to_input_join_outputs
    join = Join.new
    node = Node.new({}, join)
    
    assert_equal [node], join.outputs
  end
  
  def test_initialize_with_output_join_adds_self_to_output_join_inputs
    join = Join.new
    node = Node.new({}, nil, join)
    
    assert_equal [node], join.inputs
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_metadata_is_nil
    node = Node.new
    assert_equal nil, node.metadata
    assert node.empty?
  end
  
  def test_empty_is_true_if_metadata_is_empty
    node = Node.new({})
    assert node.empty?
    
    node.metadata[:key] = 'value'
    assert !node.empty?
  end
  
  #
  # parents test
  #
  
  def test_parents_returns_array_of_input_join_inputs
    join = Join.new [:a, :b, :c]
    node = Node.new({}, join)
    
    assert_equal [:a, :b, :c], node.parents
  end
  
  def test_parents_is_empty_array_if_input_is_not_a_join
    assert_equal nil, node.input
    assert_equal [], node.parents
  end
  
  #
  # children test
  #
  
  def test_children_returns_array_of_output_join_outputs
    join = Join.new [], [:a, :b, :c]
    node = Node.new({}, nil, join)
    
    assert_equal [:a, :b, :c], node.children
  end
  
  def test_children_is_empty_array_if_output_is_not_a_join
    assert_equal nil, node.output
    assert_equal [], node.children
  end
  
  #
  # input= test
  #
  
  def test_set_input_adds_self_to_join_outputs
    join = Join.new
    
    assert_equal [], join.outputs
    node.input = join
    assert_equal [node], join.outputs
  end
  
  def test_set_input_removes_self_from_current_input_join_outputs
    join = Join.new
    node = Node.new({}, join)
    
    assert_equal [node], join.outputs
    node.input = nil
    assert_equal [], join.outputs
  end
  
  #
  # output= test
  #
  
  def test_set_output_adds_self_to_join_inputs
    join = Join.new
    
    assert_equal [], join.inputs
    node.output = join
    assert_equal [node], join.inputs
  end
  
  def test_set_output_removes_self_from_current_output_join_inputs
    join = Join.new
    node = Node.new({}, nil, join)
    
    assert_equal [node], join.inputs
    node.output = nil
    assert_equal [], join.inputs
  end
  
end