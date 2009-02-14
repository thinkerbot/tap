require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/schema'

class SchemaUtilsTest < Test::Unit::TestCase
  include Tap::Support::Schema::Utils

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
  # format_round test
  #
  
  def test_format_round_documentation
    assert_equal "+1[1,2,3]", format_round(1, [1,2,3])
  end

  #
  # format_sequence test
  #
  
  def test_format_sequence_documentation
    assert_equal "1:2:3", format_sequence(1, [2,3], {}) 
  end
  
  #
  # format_instance test
  #

  def test_format_instance_documentation
    assert_equal "*1", format_instance(1)
  end
  
  #
  # format_fork test
  #

  def test_format_fork_documentation
    assert_equal "1[2,3]", format_fork(1, [2,3], {}) 
  end
  
  #
  # format_merge test
  #

  def test_format_merge_documentation
    assert_equal "1{2,3}", format_merge(1, [2,3], {}) 
  end
  
  #
  # format_sync_merge test
  #

  def test_format_sync_merge_documentation
    assert_equal "1(2,3)", format_sync_merge(1, [2,3], {}) 
  end
  
  #
  # format_options test
  #

  def test_format_options
    assert_equal "", format_options({})
    assert_equal "ik", format_options({:iterate => true, :stack => true})
    assert_equal "", format_options({:iterate => false, :stack => false})
  end
  
  def test_format_options_raises_error_for_unknown_options
    assert_raises(RuntimeError) { format_options(:key => 'value') }
  end
end

class SchemaTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_file_test
  
  attr_reader :schema
  
  def setup
    super
    @schema = Schema.new
  end
  
  def node_set(n=3)
    Array.new(n) {|index| Node.new([index], 0) }
  end
  
  # #
  # # Schema#load_file test
  # #
  # 
  # def test_load_file_reloads_a_yaml_dump
  #   path = method_root.prepare(:tmp, 'dump.yml') do |file|
  #     file << schema.dump.to_yaml
  #   end
  #   
  #   loaded_schema = Schema.load_file(path)
  #   assert_equal schema.dump, loaded_schema.dump
  # end
  # 
  # def test_load_file_reloads_globals
  #   schema = Schema.parse("-- a -- b -- c --*0 --*1 --*2").compact
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b -- c --*0 --*1 --*2", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_reloads_rounds
  #   schema = Schema.parse("-- a --+ b --++ c")
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b -- c --+1[1] --+2[2]", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_reloads_sequence
  #   schema = Schema.parse("-- a --: b")
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b --0:1", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_reloads_fork
  #   schema = Schema.parse("-- a -- b -- c --0[1,2]").compact
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b -- c --0[1,2]", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_reloads_merge
  #   schema = Schema.parse("-- a -- b -- c --2{0,1}").compact
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b -- c --2{0,1}", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_reloads_sync_merge
  #   schema = Schema.parse("-- a -- b -- c --2(0,1)").compact
  #   path = method_root.prepare(:tmp, 'dump.yml') {|file| file << schema.dump.to_yaml}
  #   
  #   assert_equal "-- a -- b -- c --2(0,1)", Schema.load_file(path).to_s
  # end
  # 
  # def test_load_file_initializes_new_Schema_for_empty_file
  #   path = method_root.prepare(:tmp, 'empty.yml') {}
  #   
  #   assert_equal "", File.read(path)
  #   schema = Schema.load_file(path)
  #   assert schema.kind_of?(Schema)
  #   assert schema.nodes.empty?
  # end
  # 
  # def test_load_file_raises_error_for_non_existant_file
  #   path = method_root.filepath('non_existant.yml')
  #   
  #   assert !File.exists?(path)
  #   e = assert_raises(Errno::ENOENT) { Schema.load_file(path) }
  #   assert_equal "No such file or directory - #{path}", e.message
  # end
  # 
  
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
  # set test
  #
  
  def test_set_returns_a_new_join_array
    join, inputs, outputs = schema.set(Join, [0], [1], :iterate => true)
    
    assert_equal Join, join.class
    assert_equal({:iterate => true}, join.options)
    assert_equal [schema[0]], inputs
    assert_equal [schema[1]], outputs
  end
  
  def test_set_sets_inputs_and_outputs_for_nodes_to_join_array
    join_array = schema.set(Join, [0], [1,2])
    
    assert_equal join_array, schema[0].output
    assert_equal join_array, schema[1].input
    assert_equal join_array, schema[2].input
  end
  
  def test_set_allows_single_value_inputs_and_outputs
    join_array = schema.set(Join, [0], [1])
    
    assert_equal join_array, schema[0].output
    assert_equal join_array, schema[1].input
  end
  
  def test_set_raises_error_for_orphan_join
    e = assert_raises(ArgumentError) { schema.set(Join, [], [0]) }
    assert_equal "no input nodes specified", e.message

    e = assert_raises(ArgumentError) { schema.set(Join, nil, [0]) }
    assert_equal "no input nodes specified", e.message
  end
  
  def test_set_does_not_raise_error_for_joins_with_no_target
    assert schema.set(Join, [0], [])
  end
  
  def test_set_adds_join_array_to_joins
    join_array = schema.set(Join, [0], [1,2])
    assert_equal([join_array], schema.joins)
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
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    n0.round = 0
    n1.round = 0
    n2.round = 2
  
    assert_equal [[n0, n1], nil, [n2]], schema.rounds
  end
  
  #
  # globals test
  #
  
  def test_globals_returns_a_collection_of_node_indicies_for_global_nodes
    n0, n1, n2 = Array.new(3) {|index| schema[index] }
    n0.globalize
    n2.globalize
    
    assert !n1.global?
    assert_equal [n0, n2], schema.globals
  end
  
  #
  # joins test
  #
  
  def test_joins_returns_array_of_join_arrays
    n0, n1, n2, n3, n4, n5 = Array.new(6) {|index| schema[index] }
    a = schema.set(Join, [0], [1,2])
    b = schema.set(Join, [3,4], [5])
    
    assert_equal([a,b], schema.joins)
  end
  
  #
  # cleanup test
  #
  
  def test_cleanup_removes_nil_nodes_and_nodes_where_argv_is_empty
    n0 = schema[0]
    n3 = schema[3]
    n5 = schema[5]
    
    n0.argv.concat [1,2,3]
    n5.argv.concat [4,5,6]
    
    assert_equal [n0, nil, nil, n3, nil, n5], schema.nodes
    assert n3.argv.empty?
    
    schema.cleanup
    assert_equal [n0, n5], schema.nodes
  end
  
  def test_cleanup_removes_removed_input_and_output_nodes_from_joins
    n0 = Node.new []
    n1 = Node.new [1,2,3]
    n2 = Node.new []
    n3 = Node.new [4,5,6]
    
    schema = Schema.new [n0, n1, n2, n3]
    join = schema.set(Join, [0,1], [2,3])
    
    assert_equal [n0, n1, n2, n3], schema.nodes
    assert_equal [join], schema.joins
    assert_equal [n0, n1], join[1]
    assert_equal [n2, n3], join[2]
    
    schema.cleanup
    
    assert_equal [n1, n3], schema.nodes
    assert_equal [join], schema.joins
    assert_equal [n1], join[1]
    assert_equal [n3], join[2]
  end
  
  def test_cleanup_removes_orphaned_joins
    n0 = Node.new []
    n1 = Node.new [1,2,3]
    
    schema = Schema.new [n0, n1]
    join = schema.set(Join, [0], [1])
    
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
    
    a = Node.new [1,2,3], 0
    b = Node.new [], nil
    c = Node.new [], 2
    d = Node.new [], 1
    e = Node.new [4,5,6]
    f = Node.new [7,8,9]
    
    schema = Schema.new [a,b,c,d,e,f]
    join = schema.set(Join, [1,2,3], [4,5])
    
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
  
  def test_cleanup_removes_nils_from_rounds
    n0 = schema[0] 
    n0.argv.concat [1,2,3]
    n0.round = 0
    
    n3 = schema[3]
    n3.round = 3
    
    n5 = schema[5]
    n5.argv.concat [4,5,6]
    n5.round = 5
    
    assert_equal [[n0], nil, nil, [n3], nil, [n5]], schema.rounds
    assert n3.argv.empty?
    
    schema.cleanup
    assert_equal [[n0],[n5]], schema.rounds
  end
  
  # def test_orphaned_nodes_may_shift_round_if_nil_rounds_are_removed
  #   # (3)-o-[A]
  #   #
  #   # (6)-o-[B]-o
  #   #           |
  #   # (0)-o-[C]-o-[D]
  #   
  #   join = Join.new
  #   a = Node.new [1,2,3], 3
  #   b = Node.new [], 6, join
  #   c = Node.new [], 0, join
  #   d = Node.new [4,5,6], join
  #   schema = Schema.new [a,b,c,d]
  #   
  #   assert_equal 3, a.input
  #   assert_equal 6, d.natural_round
  #   assert_equal [join], schema.joins.keys
  #   
  #   # nodes b,c removed since they have no args
  #   # then rounds look like: [nil, nil, nil, [A], nil nil, [D]]
  #   # which gets compacted to: [[A], [D]]
  #   schema.compact
  #   
  #   assert_equal [a,d], schema.nodes
  #   assert_equal 0, a.input
  #   assert_equal 1, d.input
  #   assert_equal [], schema.joins.keys
  # end
  
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
    assert_equal [[0],[1],[2]], schema.dump
  end
  
  def test_to_s_and_dump_adds_round_breaks_for_non_zero_rounds
    nodes = node_set
    nodes[0].round = 0
    nodes[1].round = 1
    nodes[2].round = 2
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --+1[1] --+2[2]", schema.to_s
    assert_equal [[0],[1],[2],"+1[1]","+2[2]"], schema.dump
  end
  
  def test_to_s_and_dump_properly_handles_multiple_tasks_in_a_round
    nodes = node_set
    nodes[0].round = 0
    nodes[1].round = 1
    nodes[2].round = 1
    
    schema = Schema.new nodes
    assert_equal "-- 0 -- 1 -- 2 --+1[1,2]", schema.to_s
    assert_equal [[0],[1],[2],"+1[1,2]"], schema.dump
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
    schema.set Join, [0], [1]
    schema.set Join, [1], [2]
    
    assert_equal "-- 0 -- 1 -- 2 --0:1 --1:2", schema.to_s
    assert_equal [[0],[1],[2],"0:1", "1:2"], schema.dump
  end
  
  def test_to_s_and_dump_adds_fork_breaks_for_fork_joins
    schema = Schema.new node_set
    schema.set Join, [0], [1,2]
  
    assert_equal "-- 0 -- 1 -- 2 --0[1,2]", schema.to_s
    assert_equal [[0],[1],[2],"0[1,2]"], schema.dump
  end
  
  def test_to_s_and_dump_adds_merge_breaks_for_merge_joins
    schema = Schema.new node_set
    schema.set Join, [0,1], [2]
  
    assert_equal "-- 0 -- 1 -- 2 --2{0,1}", schema.to_s
    assert_equal [[0],[1],[2],"2{0,1}"], schema.dump
  end
  
  def test_to_s_and_dump_adds_sync_merge_breaks_for_sync_merge_joins
    schema = Schema.new node_set
    schema.set Joins::SyncMerge, [0,1], [2]
  
    assert_equal "-- 0 -- 1 -- 2 --2(0,1)", schema.to_s
    assert_equal [[0],[1],[2],"2(0,1)"], schema.dump
  end
  
  # def test_to_s_and_dump_raises_error_for_unknown_join_type
  #   schema = Schema.new node_set
  #   schema.set :unknown, 0, [1]
  # 
  #   assert_raises(RuntimeError) { schema.to_s }
  #   assert_raises(RuntimeError) { schema.dump }
  # end

end