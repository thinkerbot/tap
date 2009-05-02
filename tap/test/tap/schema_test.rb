require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/schema'
require 'tap/root'

class SchemaTest < Test::Unit::TestCase
  Schema = Tap::Schema
  Node = Tap::Schema::Node
  Join = Tap::Schema::Join

  attr_reader :schema
  
  def setup
    super
    @schema = Schema.new
  end

  def node_set(n=3)
    Array.new(n) {|index| Node.new([index]) }
  end
  
  #
  # Schema#load test
  #
  
  def test_load_reloads_a_yaml_dump
    argh = schema.dump
    loaded_schema = Schema.load(argh)
    assert_equal schema.dump, loaded_schema.dump
  end
  
  def test_load_reloads_nodes_and_join
    schema = Schema.parse("-- a 1 2 -- b 3 4 -- c --[0][1,2]")
    argh = schema.dump
    
    schema = Schema.load(argh)
    assert_equal [["a", "1", "2"], ["b", "3", "4"], ["c"]], schema.metadata
    
    join = schema[0].output
    assert_equal [schema[0]], join.inputs
    assert_equal [schema[1], schema[2]], join.outputs
    assert_equal(['join'], join.metadata)
  end
  
  def test_load_reloads_nodes_and_join_hashes
    n0 = Node.new :args => [1,2,3]
    n1 = Node.new :args => [4,5,6]
    
    schema = Schema.new [n0, n1]
    schema.set_join([0], [1], :key => 'value')
    
    argh = schema.dump
    schema = Schema.load(argh)
    
    assert_equal [{:args => [1,2,3]}, {:args => [4,5,6]}], schema.metadata
    
    join = schema[0].output
    assert_equal [schema[0]], join.inputs
    assert_equal [schema[1]], join.outputs
    assert_equal({:key => 'value'}, join.metadata)
  end
  
  def test_load_initializes_new_Schema_for_empty_string
    schema = Schema.load ""
    assert schema.kind_of?(Schema)
    assert schema.nodes.empty?
  end
  
  #
  # [] test
  #
  
  def test_AGET_returns_node_at_index
    schema = Schema.new [:a, :b, :c]
    
    assert_equal [:a, :b, :c], schema.nodes
    assert_equal :a, schema[0]
    assert_equal :c, schema[2]
  end
  
  def test_AGET_instantiates_new_node_at_index_if_nodes_is_nil_at_index
    schema = Schema.new
    assert_equal [], schema.nodes
    
    node = schema[1]
    assert_equal Node, node.class
    assert_equal [nil, node], schema.nodes
  end
  
  #
  # index test
  #
  
  def test_index_returns_the_index_of_a_node_in_nodes
    schema = Schema.new [:a, :b, :c]
    
    assert_equal 0, schema.index(:a)
    assert_equal 2, schema.index(:c)
    assert_equal nil, schema.index(:non_existant)
  end
  
  #
  # set_join test
  #
  
  def test_set_join_returns_a_new_join
    join = schema.set_join([0], [1], :modifier => "i")
    
    assert_equal({:modifier => "i"}, join.metadata)
    assert_equal [schema[0]], join.inputs
    assert_equal [schema[1]], join.outputs
  end
  
  def test_set_join_sets_inputs_and_outputs_for_nodes_to_join_array
    join_array = schema.set_join([0], [1,2])
    
    assert_equal join_array, schema[0].output
    assert_equal join_array, schema[1].input
    assert_equal join_array, schema[2].input
  end
  
  def test_set_join_allows_single_value_inputs_and_outputs
    join_array = schema.set_join([0], [1])
    
    assert_equal join_array, schema[0].output
    assert_equal join_array, schema[1].input
  end
  
  def test_set_join_adds_join_array_to_joins
    join_array = schema.set_join([0], [1,2])
    assert_equal([join_array], schema.joins)
  end
  
  #
  # joins test
  #
  
  def test_joins_returns_array_of_join_arrays
    n0, n1, n2, n3, n4, n5 = Array.new(6) {|index| schema[index] }
    a = schema.set_join([0], [1,2])
    b = schema.set_join([3,4], [5])
    
    assert_equal([a,b], schema.joins)
  end
  
  #
  # cleanup test
  #
  
  def test_cleanup_removes_nil_and_empty_nodes
    n0 = schema[0]
    n3 = schema[3]
    n5 = schema[5]
    
    n0.metadata = [1,2,3]
    n5.metadata = [4,5,6]
    
    assert_equal [n0, nil, nil, n3, nil, n5], schema.nodes
    assert n3.empty?
    
    schema.cleanup
    assert_equal [n0, n5], schema.nodes
  end
  
  def test_cleanup_removes_removed_input_and_output_nodes_from_joins
    n0 = Node.new
    n1 = Node.new [1,2,3]
    n2 = Node.new
    n3 = Node.new [4,5,6]
    
    schema = Schema.new [n0, n1, n2, n3]
    join = schema.set_join([0,1], [2,3])
    
    assert_equal [n0, n1, n2, n3], schema.nodes
    assert_equal [join], schema.joins
    assert_equal [n0, n1], join.inputs
    assert_equal [n2, n3], join.outputs
    
    schema.cleanup
    
    assert_equal [n1, n3], schema.nodes
    assert_equal [join], schema.joins
    assert_equal [n1], join.inputs
    assert_equal [n3], join.outputs
  end
  
  def test_cleanup_removes_orphaned_joins
    n0 = Node.new
    n1 = Node.new [1,2,3]
    
    schema = Schema.new [n0, n1]
    join = schema.set_join([0], [1])
    
    assert_equal [n0, n1], schema.nodes
    assert_equal [join], schema.joins
    
    schema.cleanup
    
    assert_equal [n1], schema.nodes
    assert_equal [], schema.joins
  end
  
  def test_cleanup_removes_orphan_joins
    join = Join.new
    a = Node.new [1,2,3], join
    b = Node.new [3,4,5], join
    
    schema = Schema.new [a,b]
    assert_equal join, a.input
    assert_equal join, b.input
    assert_equal [a,b], join.outputs
    
    schema.cleanup
    
    assert_equal nil, a.input
    assert_equal nil, b.input
  end
  
  def test_cleanup_returns_self
    assert_equal schema, schema.cleanup
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_for_an_empty_schema
    schema = Schema.new
    assert_equal({}, schema.to_hash)
  end
  
  def test_to_hash_adds_node_metadata
    schema = Schema.new node_set
    assert_equal({
      :nodes => [[0],[1],[2]]
    }, schema.to_hash)
  end
  
  def test_to_hash_adds_join_inputs_outputs_and_non_hash_metadata
    schema = Schema.new node_set
    schema.set_join [0,1], [2], ['join']
  
    assert_equal [
      [[0,1], [2], ['join']]
    ], schema.to_hash[:joins]
  end
  
  def test_to_hash_adds_join_inputs_outputs_to_hash_metadata
    schema = Schema.new node_set
    schema.set_join [0,1], [2], :key => 'value'
  
    assert_equal [
      {:key => 'value', :inputs => [0,1], :outputs => [2]}
    ], schema.to_hash[:joins]
  end
  
  def test_to_hash_performs_cleanup
    join = Join.new
    a = Node.new(["a"])
    b = Node.new(["b"], join)
    c = Node.new(["c"], join)
    
    schema = Schema.new [a, b, nil, c]
    assert_equal({
      :nodes => [['a'],['b'],['c']],
    }, schema.to_hash)
  end
end