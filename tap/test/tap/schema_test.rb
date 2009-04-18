require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/schema'
require 'tap/root'

class SchemaUtilsTest < Test::Unit::TestCase
  include Tap::Schema::Utils

  #
  # shell_quote test
  #
  
  def test_shell_quote
    assert_equal "str", shell_quote("str")
    assert_equal ["a", "str", "b"], Shellwords.shellwords("a str b")
    
    assert_equal %Q{'no "quote"'}, shell_quote("no \"quote\"")
    assert_equal ["a", "no \"quote\"", "b"], Shellwords.shellwords(%Q{a 'no "quote"' b})
    
    assert_equal %Q{"no 'double quote'"}, shell_quote("no 'double quote'")
    assert_equal ["a", "no 'double quote'", "b"], Shellwords.shellwords(%Q{a "no 'double quote'" b})
    
    assert_raises(ArgumentError) { shell_quote("\"quote\" and 'double quote'") }
  end
  
  #
  # round_arg test
  #
  
  def test_round_arg_documentation
    assert_equal "+1[1,2,3]", round_arg(1, [1,2,3])
  end
  
  #
  # prerequiste_arg test
  #

  def test_prerequiste_arg_documentation
    assert_equal "*[1]", prerequiste_arg([1])
    assert_equal "*[1,2,3]", prerequiste_arg([1,2,3])
  end
  
  #
  # join_arg test
  #

  def test_join_arg_documentation
    assert_equal "[1][2,3].type", join_arg([1], [2,3], ['type']) 
  end
  
  def test_join_arg
    assert_equal "[1][2,3]is.type", join_arg([1], [2,3], ['type', 'is']) 
    assert_equal "[1][2,3]is", join_arg([1], [2,3], ['join', 'is'])
    assert_equal "[1][2,3]", join_arg([1], [2,3], ['join', '']) 
    assert_equal "[1][2,3]", join_arg([1], [2,3], ['join', nil]) 
    assert_equal "[1][2,3]", join_arg([1], [2,3], []) 
    assert_equal "[1][2,3]", join_arg([1], [2,3]) 
  end
end

class SchemaTest < Test::Unit::TestCase
  Schema = Tap::Schema
  Node = Tap::Schema::Node
  include MethodRoot
  
  attr_reader :schema
  
  def setup
    super
    @schema = Schema.new
  end

  def node_set(n=3)
    Array.new(n) {|index| Node.new([index]) }
  end
  
  #
  # Schema#load_file test
  #
  
  def test_load_file_reloads_a_yaml_dump
    path = method_root.prepare(:tmp, 'dump.yml') do |file|
      file << YAML.dump(schema.dump)
    end
    
    loaded_schema = Schema.load_file(path)
    assert_equal schema.dump, loaded_schema.dump
  end
  
  def test_load_file_reloads_prerequisites
    schema = Schema.parse("-- a -- b -- c --*[0,1] --*[2]")
    path = method_root.prepare(:tmp, 'dump.yml') {|file| file << YAML.dump(schema.dump)}
    
    assert_equal "-- a -- b -- c --*[0,1,2]", Schema.load_file(path).to_s
  end
  
  def test_load_file_reloads_rounds
    schema = Schema.parse("-- a --+ b --++ c")
    path = method_root.prepare(:tmp, 'dump.yml') {|file| file << YAML.dump(schema.dump)}
    
    assert_equal "-- a -- b -- c --+1[1] --+2[2]", Schema.load_file(path).to_s
  end
  
  def test_load_file_reloads_sequence
    schema = Schema.parse("-- a --: b")
    path = method_root.prepare(:tmp, 'dump.yml') {|file| file << YAML.dump(schema.dump)}
    
    assert_equal "-- a -- b --[0][1]", Schema.load_file(path).to_s
  end
  
  def test_load_file_reloads_fork
    schema = Schema.parse("-- a -- b -- c --[0][1,2]")
    path = method_root.prepare(:tmp, 'dump.yml') {|file| file << YAML.dump(schema.dump)}
    
    assert_equal "-- a -- b -- c --[0][1,2]", Schema.load_file(path).to_s
  end
  
  def test_load_file_reloads_merge
    schema = Schema.parse("-- a -- b -- c --[0,1][2]")
    path = method_root.prepare(:tmp, 'dump.yml') {|file| file << YAML.dump(schema.dump)}
    
    assert_equal "-- a -- b -- c --[0,1][2]", Schema.load_file(path).to_s
  end
  
  def test_load_file_initializes_new_Schema_for_empty_file
    path = method_root.prepare(:tmp, 'empty.yml') {}
    
    assert_equal "", File.read(path)
    schema = Schema.load_file(path)
    assert schema.kind_of?(Schema)
    assert schema.nodes.empty?
  end
  
  def test_load_file_raises_error_for_non_existant_file
    path = method_root.path('non_existant.yml')
    
    assert !File.exists?(path)
    e = assert_raises(Errno::ENOENT) { Schema.load_file(path) }
    assert_equal "No such file or directory - #{path}", e.message
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
  # metadata test
  #
  
  def test_metadata_returns_a_collection_of_metadata_across_all_nodes
    schema = Schema.new
    schema[0].metadata = {:args => [1,2,3]}
    schema[2].metadata = [4,5,6]
    
    assert_equal [{:args => [1,2,3]}, nil, [4,5,6]], schema.metadata
  end
  
  #
  # set_round test
  #
  
  def test_set_round_sets_the_round_for_the_specified_nodes
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    n0.round = 0
    n1.round = 0
    n2.round = 2
  
    assert_equal [[n0, n1], nil, [n2]], schema.rounds
    
    schema.set_round(1, [0,2])
    
    assert_equal [[n1], [n0, n2]], schema.rounds
  end
  
  #
  # set_prerequisites test
  #
  
  def test_set_prerequisites_sets_the_specified_nodes_as_prerequisites
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    assert !n0.prerequisite?
    assert !n1.prerequisite?
    assert !n2.prerequisite?
    
    schema.set_prerequisites([0,2])
    assert_equal [n0, n2], schema.prerequisites
  end
  
  #
  # set_join test
  #
  
  def test_set_join_returns_a_new_join_array
    inputs, outputs, metadata = schema.set_join([0], [1], :modifier => "i")
    
    assert_equal({:modifier => "i"}, metadata)
    assert_equal [schema[0]], inputs
    assert_equal [schema[1]], outputs
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
  # rounds test
  #
  
  def test_rounds_returns_a_collection_of_node_indicies_sorted_into_arrays_by_round
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    n0.round = 0
    n1.round = 0
    n2.round = 2
  
    assert_equal [[n0, n1], nil, [n2]], schema.rounds
  end
  
  #
  # natural_rounds test
  #
  
  def test_natural_rounds_returns_a_collection_of_node_indicies_sorted_into_arrays_by_natural_rounds
    # (3)-o-[A]-o-[C]-o-[D]
    #           |
    # (2)-o-[B]-o
  
    join1, join2 = Array.new(2) { [[], []] }
    a = Node.new({}, 3, join1)
    b = Node.new({}, 2, join1)
    c = Node.new({}, join1, join2)
    d = Node.new({}, join2)
    
    schema = Schema.new([a,b,c,d])
    assert_equal [nil, nil, [b,c,d], [a]], schema.natural_rounds
  end
  
  #
  # prerequisites test
  #
  
  def test_prerequisites_returns_a_collection_of_node_indicies_for_prerequisite_nodes
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    n0.make_prerequisite
    n2.make_prerequisite
    
    assert !n1.prerequisite?
    assert_equal [n0, n2], schema.prerequisites
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
    assert_equal [n0, n1], join[0]
    assert_equal [n2, n3], join[1]
    
    schema.cleanup
    
    assert_equal [n1, n3], schema.nodes
    assert_equal [join], schema.joins
    assert_equal [n1], join[0]
    assert_equal [n3], join[1]
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
  
  def test_cleanup_sets_orphaned_join_outputs_to_natural_round_of_join_inputs
    # (0)-o-[A]
    #
    # ( )-o-[B]-o
    #           |
    # (2)-o-[C]-o
    #           |
    # (1)-o-[D]-o-[E]
    #           |
    #           o-[F]
    
    a = Node.new([1,2,3], 0)
    b = Node.new({}, nil)
    c = Node.new({}, 2)
    d = Node.new({}, 1)
    e = Node.new [4,5,6]
    f = Node.new [7,8,9]
    
    schema = Schema.new [a,b,c,d,e,f]
    join = schema.set_join([1,2,3], [4,5])
    
    assert_equal 0, a.input
    assert_equal 1, e.natural_round
    assert_equal [join], schema.joins
    
    # nodes b,c,d are all removed since they have no args
    schema.cleanup
    
    assert_equal [a,e,f], schema.nodes
    assert_equal 0, a.input
    assert_equal 1, e.input
    assert_equal 1, f.input
    assert_equal [], schema.joins
  end
  
  def test_cleanup_removes_orphan_joins
    join = [[], []]
    a = Node.new [1,2,3], join
    b = Node.new [3,4,5], join
    
    schema = Schema.new [a,b]
    assert_equal join, a.input
    assert_equal join, b.input
    assert_equal [[],[a,b]], join
    
    schema.cleanup
    
    assert_equal 0, a.input
    assert_equal 0, b.input
  end
  
  def test_cleanup_removes_nils_from_rounds
    n0 = schema[0] 
    n0.metadata = [1,2,3]
    n0.round = 0
    
    n3 = schema[3]
    n3.round = 3
    
    n5 = schema[5]
    n5.metadata = [4,5,6]
    n5.round = 5
    
    assert_equal [[n0], nil, nil, [n3], nil, [n5]], schema.rounds
    assert n3.empty?
    
    schema.cleanup
    assert_equal [[n0],[n5]], schema.rounds
  end
  
  def test_cleanup_returns_self
    assert_equal schema, schema.cleanup
  end
  
  #
  # build test
  #
  
  #
  # dump/to_s test
  #
  
  def test_to_s_and_dump_for_an_empty_schema
    schema = Schema.new
    assert_equal "", schema.to_s
    assert_equal [], schema.dump
  end
  
  def test_to_s_and_dump_formats_argvs_separated_by_break
    schema = Schema.new node_set
    assert_equal "-- 0 -- 1 -- 2", schema.to_s
    assert_equal [[0],[1],[2]], schema.dump(true)
  end
  
  def test_to_s_and_dump_perform_cleanup
    join = [[], [], ""]
    a = Node.new(["a"], 2)
    b = Node.new(["b"], join)
    c = Node.new(["c"], join)
    
    schema = Schema.new [a,b,nil,c]
    assert_equal "-- a -- b -- c --+1[0]", schema.to_s
    assert_equal [['a'],['b'],['c'], "+1[0]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_round_breaks_for_non_zero_rounds
    nodes = node_set
    nodes[0].round = 0
    nodes[1].round = 1
    nodes[2].round = 2
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --+1[1] --+2[2]", schema.to_s
    assert_equal [[0],[1],[2],"+1[1]","+2[2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_properly_handles_multiple_tasks_in_a_round
    nodes = node_set
    nodes[0].round = 0
    nodes[1].round = 1
    nodes[2].round = 1
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --+1[1,2]", schema.to_s
    assert_equal [[0],[1],[2],"+1[1,2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_global_breaks_for_prerequisite_nodes
    nodes = node_set
    nodes[1].make_prerequisite
    nodes[2].make_prerequisite
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --*[1,2]", schema.to_s
    assert_equal [[0],[1],[2],"*[1,2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_sequence_breaks_for_sequence_joins
    schema = Schema.new node_set
    schema.set_join [0], [1]
    schema.set_join [1], [2]
    
    assert_equal "-- 0 -- 1 -- 2 --[0][1] --[1][2]", schema.to_s
    assert_equal [[0],[1],[2],"[0][1]", "[1][2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_fork_breaks_for_fork_joins
    schema = Schema.new node_set
    schema.set_join [0], [1,2]
  
    assert_equal "-- 0 -- 1 -- 2 --[0][1,2]", schema.to_s
    assert_equal [[0],[1],[2],"[0][1,2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_merge_breaks_for_merge_joins
    schema = Schema.new node_set
    schema.set_join [0,1], [2]
  
    assert_equal "-- 0 -- 1 -- 2 --[0,1][2]", schema.to_s
    assert_equal [[0],[1],[2],"[0,1][2]"], schema.dump(true)
  end
  
  def test_to_s_and_dump_adds_sync_merge_breaks_for_arbitrary_joins
    schema = Schema.new node_set
    schema.set_join [0,1], [2], ["type"]
  
    assert_equal "-- 0 -- 1 -- 2 --[0,1][2].type", schema.to_s
    assert_equal [[0],[1],[2],"[0,1][2].type"], schema.dump(true)
  end
  
  #
  # misc tests
  #
  
  # def test_schema_loads_terminal_joins_correctly
  #   schema = Schema.load [["a"], ["b"], "[0][]"]
  #   assert_equal 2, schema.nodes.length
  #   
  #   a,b = schema.nodes
  #   
  #   assert_equal [[a,b]], schema.rounds
  #   assert_equal [[a,b]], schema.natural_rounds
  # end
end