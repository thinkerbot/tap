require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/schema'
require 'shellwords'

class SchemaTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :schema
  
  def setup
    @schema = Schema.new
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
    assert_equal [], schema.nodes
    node = schema[1]
    assert_equal Node, node.class
    assert_equal [nil, node], schema.nodes
  end
  
  #
  # argvs test
  #
  
  def test_argvs_returns_a_collection_of_all_argvs_across_nodes
    schema[0].argv = [1,2,3]
    schema[1].argv = [4,5,6]
    
    assert_equal [[1,2,3], [4,5,6]], schema.argvs
  end
  
  #
  # rounds test
  #
  
  def test_rounds_returns_a_collection_of_node_indicies_sorted_into_arrays_by_round
    n0 = Node.new [], 0
    n1 = Node.new [], 0
    n2 = Node.new [], :ignored
    n5 = Node.new [], 2
    
    schema = Schema.new [n0, n1, n2, nil, nil, n5]
    assert_equal [[0, 1], nil, [5]], schema.rounds
  end
  
  #
  # globals test
  #
  
  def test_globals_returns_a_collection_of_node_indicies_for_global_nodes
    n0 = Node.new [], :not_global
    n1 = Node.new []
    n2 = Node.new [], nil, :not_global
    n5 = Node.new []
    
    schema = Schema.new [n0, n1, n2, nil, nil, n5]
    assert_equal [1, 5], schema.globals
  end
  
  #
  # joins test
  #
  
  def test_joins_returns_a_collection_of_joins_resolved_as_indicies
    n0, n1, n2, n3, n4, n5 = Array.new(6) { Node.new }
    a = Node::Join.new(:a, :options)
    b = Node::Join.new(:b, :options)
    
    n0.output = a
    n1.input = a
    n2.input = a
    
    n3.output = b
    n4.output = b
    n5.input = b

    schema = Schema.new [n0, n1, n2, n3, n4, n5]
    assert_equal({
      a => [[0], [1,2]], 
      b => [[3,4], [5]]
    }, schema.joins)
  end
  
  #
  # to_s test
  #

  # def test_to_s_returns_argv_string
  #   n0, n1, n2, n3, n4, n5 = Array.new(6) {|index| Node.new(["#{index}", "-#{index}"]) }
  #   a = Node::Join.new(:fork, :options)
  #   b = Node::Join.new(:merge, :options)
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
  # 
  #   puts schema.to_s
  # end
  # 
  # #
  # # dump test
  # #
  # 
  # def test_dump_returns_array_dump_of_tasks_and_workflow_declarations
  #   p = Parser.new
  #   p.tasks.concat [
  #     ["a", "a1", "a2", "--key", "value", "--another", "another value"],
  #     ["b", "b1"],
  #     ["c"]
  #   ]
  #   
  #   p.rounds_map.concat [2,2,1]
  #   p.workflow_map.concat [
  #     [:sequence, 1, ''],
  #     [:sequence, 2, ''],
  #     [:fork, [1,2,3], ''],
  #     [:merge, 6, ''],
  #     [:merge, 6, '']
  #   ]
  #   
  #   assert_equal [
  #     ["a", "a1", "a2", "--key", "value", "--another", "another value"],
  #     ["b", "b1"],
  #     ["c"],
  #     "+1[2]",
  #     "+2[0,1]",
  #     "0:1",
  #     "1:2",
  #     "2[1,2,3]",
  #     "6{3,4}"
  #   ], p.dump
  #   
  #   # now, check for consistency
  #   p = Parser.load p.dump
  #   assert_equal [
  #     ["a", "a1", "a2", "--key", "value", "--another", "another value"],
  #     ["b", "b1"],
  #     ["c"]
  #   ], p.tasks
  # 
  #   assert_equal [2, nil, nil, nil, nil, nil, nil], p.rounds_map
  #   assert_equal [
  #     [:sequence, 1, ''],
  #     [:sequence, 2, ''],
  #     [:fork, [1,2,3], ''],
  #     [:merge, 6, ''],
  #     [:merge, 6, '']
  #   ], p.workflow_map
  # end
end