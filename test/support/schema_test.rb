require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/schema'
require 'shellwords'

class SchemaTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :schema, :nodes, :n0, :n1, :n2, :n3, :n4, :n5
  
  def setup
    @nodes = Array.new(6) { Node.new }
    @schema = Schema.new @nodes
    @n0, @n1, @n2, @n3, @n4, @n5 = @nodes
  end
  
  def node_set(n=3)
    Array.new(n) {|index| Node.new([index], 0) }
  end
  
  #
  # Schema.shell_quote test
  #
  
  def test_shell_quote
    assert_equal "str", Schema.shell_quote("str")
    assert_equal ["a", "str", "b"], Shellwords.shellwords("a str b")
    
    assert_equal %Q{'no "quote"'}, Schema.shell_quote("no \"quote\"")
    assert_equal ["a", "no \"quote\"", "b"], Shellwords.shellwords(%Q{a 'no "quote"' b})
    
    assert_equal %Q{"no 'double quote'"}, Schema.shell_quote("no 'double quote'")
    assert_equal ["a", "no 'double quote'", "b"], Shellwords.shellwords(%Q{a "no 'double quote'" b})
    
    assert_raise(ArgumentError) { Schema.shell_quote("\"quote\" and 'double quote'") }
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
  # set test
  #
  
  def test_set_returns_a_new_join
    join = schema.set(:type, {}, [], [])
    
    assert_equal Node::Join, join.class
    assert_equal :type, join.type
    assert_equal({}, join.options)
  end
  
  def test_set_sets_inputs_and_outputs_for_specified_nodes_to_the_new_join
    join = schema.set(:type, {}, [0,1], [2,3])
    
    assert_equal join, n0.output
    assert_equal join, n1.output
    assert_equal join, n2.input
    assert_equal join, n3.input
  end
  
  #
  # compact test
  #
  
  def test_compact_removes_nil_nodes_and_nodes_where_argv_is_empty
    n0 = Node.new [1,2,3]
    n3 = Node.new []
    n5 = Node.new [4,5,6]
    
    schema = Schema.new [n0, nil, nil, n3, nil, n5]
    schema.compact
    assert_equal [n0, n5], schema.nodes
  end
  
  def test_compact_removes_nils_from_rounds
    n0 = Node.new [1,2,3]
    n0.round = 0
    
    n3 = Node.new []
    n3.round = 3
    
    n5 = Node.new [4,5,6]
    n5.round = 5
    
    schema = Schema.new [n0, nil, nil, n3, nil, n5]
    assert_equal [[n0], nil, nil, [n3], nil, [n5]], schema.rounds
    
    schema.compact
    assert_equal [[n0],[n5]], schema.rounds
  end
  
  def test_compact_returns_self
    assert_equal schema, schema.compact
  end

  #
  # argvs test
  #
  
  def test_argvs_returns_a_collection_of_all_argvs_across_nodes
    schema = Schema.new
    schema[0].argv = [1,2,3]
    schema[2].argv = [4,5,6]
    
    assert_equal [[1,2,3], nil, [4,5,6]], schema.argvs
  end
  
  #
  # rounds test
  #
  
  def test_rounds_returns_a_collection_of_node_indicies_sorted_into_arrays_by_round
    n0.input = 0
    n1.input = 0
    n5.input = 2

    assert_equal [[n0, n1], nil, [n5]], schema.rounds
  end
  
  #
  # globals test
  #
  
  def test_globals_returns_a_collection_of_node_indicies_for_global_nodes
    n0.globalize
    n5.globalize
    [n1,n2,n3,n4].each {|n| n.input = :input }
    
    assert_equal [n0, n5], schema.globals
  end
  
  #
  # joins test
  #
  
  def test_join_hash_returns_hash_of_input_and_output_nodes_by_join
    a = schema.set(:a, :options, [0], [1,2])
    b = schema.set(:b, :options, [3,4], [5])
    
    assert_equal({
      a => [[n0], [n1,n2]], 
      b => [[n3,n4], [n5]]
    }, schema.join_hash)
  end
  
  # #
  # # joins_by_type test
  # #
  # 
  # def test_joins_by_type
  #   n0, n1, n2, n3, n4, n5 = Array.new(6) { Node.new }
  #   a = Node::Join.new(:a, :options)
  #   b = Node::Join.new(:b, :options)
  #   
  #   n0.output = a
  #   n1.input = a
  #   n2.input = a
  #   
  #   n3.output = b
  #   n4.output = b
  #   n5.input = b
  # 
  #   schema = Schema.new [n0, n1, n2, n3, n4, n5]
  #   assert_equal({
  #     :a => [
  #       [[n0], [n1,n2], :options]],
  #     :b => [
  #       [[n3,n4], [n5], :options]]
  #   }, schema.joins_by_type)
  # end
  
  #
  # dump/to_s test
  #
  
  def test_to_s_and_dump_formats_argvs_separated_by_break
    schema = Schema.new node_set
    assert_equal "-- 0 -- 1 -- 2", schema.to_s
    assert_equal [[0],[1],[2]], schema.dump
  end
  
  def test_to_s_and_dump_adds_breaks_for_nil_nodes
    nodes = node_set
    nodes[1] = nil
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- -- 2", schema.to_s
    assert_equal [[0],nil,[2]], schema.dump
  end
  
  def test_to_s_and_dump_adds_breaks_for_empty_nodes
    nodes = node_set
    nodes[1].argv.clear
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- -- 2", schema.to_s
    assert_equal [[0],[],[2]], schema.dump
  end
  
  def test_to_s_and_dump_adds_round_breaks_for_non_zero_rounds
    nodes = node_set
    nodes[0].round = 2
    nodes[1].round = 2
    nodes[2].round = 1
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --+1[2] --+2[0,1]", schema.to_s
    assert_equal [[0],[1],[2],"+1[2]","+2[0,1]"], schema.dump
  end
  
  def test_to_s_and_dump_adds_global_breaks_for_global_nodes
    nodes = node_set
    nodes[1].globalize
    nodes[2].globalize
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --*1 --*2", schema.to_s
    assert_equal [[0],[1],[2],"*1","*2"], schema.dump
  end
  
  def test_to_s_and_dump_adds_sequence_breaks_for_sequence_joins
    schema = Schema.new node_set
    schema.set :sequence, {}, [0], [1,2]

    assert_equal "-- 0 -- 1 -- 2 --0:1:2", schema.to_s
    assert_equal [[0],[1],[2],"0:1:2"], schema.dump
  end
  
  def test_to_s_and_dump_adds_fork_breaks_for_fork_joins
    schema = Schema.new node_set
    schema.set :fork, {}, [0], [1,2]

    assert_equal "-- 0 -- 1 -- 2 --0[1,2]", schema.to_s
    assert_equal [[0],[1],[2],"0[1,2]"], schema.dump
  end
  
  def test_to_s_and_dump_adds_merge_breaks_for_merge_joins
    schema = Schema.new node_set
    schema.set :merge, {}, [0,1], [2]

    assert_equal "-- 0 -- 1 -- 2 --2{0,1}", schema.to_s
    assert_equal [[0],[1],[2],"2{0,1}"], schema.dump
  end
  
  def test_to_s_and_dump_adds_sync_merge_breaks_for_sync_merge_joins
    schema = Schema.new node_set
    schema.set :sync_merge, {}, [0,1], [2]

    assert_equal "-- 0 -- 1 -- 2 --2(0,1)", schema.to_s
    assert_equal [[0],[1],[2],"2(0,1)"], schema.dump
  end
  
  def test_to_s_and_dump_raises_error_for_unknown_join_type
    schema = Schema.new node_set
    schema.set :unknown, {}, [0], [1]

    assert_raise(RuntimeError) { schema.to_s }
    assert_raise(RuntimeError) { schema.dump }
  end

end