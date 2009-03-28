require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/schema'
require 'yaml'

class ParserUtilsTest < Test::Unit::TestCase
  include Tap::Support::Parser::Utils

  def previous_index
    :previous_index
  end

  def current_index
    :current_index
  end
  
  #
  # bracket_regexp test
  #
  
  def test_bracket_regexp
    r = bracket_regexp("[", "]")
    
    assert "[]" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "", $3
    
    assert "1[]" =~ r
    assert_equal "1", $1
    assert_equal "", $2
    assert_equal "", $3
    
    assert "[2]" =~ r
    assert_equal "", $1
    assert_equal "2", $2
    assert_equal "", $3
    
    assert "1[2]" =~ r
    assert_equal "1", $1
    assert_equal "2", $2
    assert_equal "", $3
    
    assert "1[2,3,4]" =~ r
    assert_equal "1", $1
    assert_equal "2,3,4", $2
    assert_equal "", $3
  
    assert "100[200,300,400]" =~ r
    assert_equal "100", $1
    assert_equal "200,300,400", $2
    assert_equal "", $3
    
    assert "[]i" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "i", $3
    
    assert "[]is" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "is", $3
    
    assert "1[2,3,4]is" =~ r
    assert_equal "1", $1
    assert_equal "2,3,4", $2
    assert_equal "is", $3
    
    # non-matching
    assert "1" !~ r
    assert "[]1" !~ r
    assert "1[2,3,4]1" !~ r
    assert "1[2, 3, 4]" !~ r
  end
  
  #
  # BREAK test
  #
  
  def test_BREAK_regexp
    r = BREAK
    
    assert "--" =~ r
    assert_equal "", $1
    
    assert "--+" =~ r
    assert_equal "+", $1
    
    assert "--+2" =~ r
    assert_equal "+2", $1
    
    assert "--:" =~ r
    assert_equal ":", $1
    
    assert "--1:2:3" =~ r
    assert_equal "1:2:3", $1
    
    assert "--[]" =~ r
    assert_equal "[]", $1
    
    assert "--1[2,3]" =~ r
    assert_equal "1[2,3]", $1
    
    assert "--()" =~ r
    assert_equal "()", $1
    
    assert "--1(2,3)" =~ r
    assert_equal "1(2,3)", $1
    
    assert "--{}" =~ r
    assert_equal "{}", $1
    
    assert "--1{2,3}" =~ r
    assert_equal "1{2,3}", $1
    
    assert "--*" =~ r
    assert_equal "*", $1
    
    assert "--*1" =~ r
    assert_equal "*1", $1
    
    # non-matching
    assert "goodnight" !~ r
    assert "moon" !~ r
    assert "8" !~ r
    
    assert "-" !~ r
    assert "---" !~ r
    assert " -- " !~ r
    assert "-- " !~ r
    assert " --" !~ r
    
    assert "-o" !~ r
    assert "-opt" !~ r
    assert "--opt" !~ r
    assert "--no-opt" !~ r
  end
  
  #
  # ROUND test
  #

  def test_ROUND_regexp
    r = ROUND

    # plus syntax
    assert "" =~ r
    assert_equal nil, $2
    assert_equal nil, $5

    assert "+" =~ r
    assert_equal "+", $2
    assert_equal nil, $5

    assert "++" =~ r
    assert_equal "++", $2
    assert_equal nil, $5

    assert "+++" =~ r
    assert_equal "+++", $2
    assert_equal nil, $5

    assert "++[]" =~ r
    assert_equal "++", $2
    assert_equal "", $5

    assert "++[1,2,3]" =~ r
    assert_equal "++", $2
    assert_equal "1,2,3", $5

    # plus-number syntax
    assert "+0" =~ r
    assert_equal "+0", $2
    assert_equal nil, $5

    assert "+1" =~ r
    assert_equal "+1", $2
    assert_equal nil, $5

    assert "+100" =~ r
    assert_equal "+100", $2
    assert_equal nil, $5

    assert "+1[]" =~ r
    assert_equal "+1", $2
    assert_equal "", $5

    assert "+1[1,2,3]" =~ r
    assert_equal "+1", $2
    assert_equal "1,2,3", $5

    # non-matching
    assert "-" !~ r
    assert "-a" !~ r
    assert "--a" !~ r
    assert "--+a" !~ r
    assert "--+1[a]" !~ r
  end

  #
  # SEQUENCE test
  #
  
  def test_SEQUENCE_regexp
    r = SEQUENCE
    
    assert ":" =~ r
    assert_equal ":", $1
    assert_equal "", $3
    
    assert "1:2" =~ r
    assert_equal "1:2", $1
    assert_equal "", $3
    
    assert "1:" =~ r
    assert_equal "1:", $1
    assert_equal "", $3
    
    assert ":2" =~ r
    assert_equal ":2", $1
    assert_equal "", $3
    
    assert "100:200" =~ r
    assert_equal "100:200", $1
    assert_equal "", $3
    
    assert "1:2:3" =~ r
    assert_equal "1:2:3", $1
    assert_equal "", $3
  
    assert ":i" =~ r
    assert_equal ":", $1
    assert_equal "i", $3
    
    assert "1:2is" =~ r
    assert_equal "1:2", $1
    assert_equal "is", $3
    
    # non-matching
    assert "--1" !~ r
    assert "-- 1 : 2" !~ r
    assert "1" !~ r
    assert "--i" !~ r
  end
  
  #
  # PREREQUISITE test
  #
  
  def test_PREREQUISITE_regexp
    r = PREREQUISITE
    
    assert "*" =~ r
    assert_equal "", $1
  
    assert "*1" =~ r
    assert_equal "1", $1
    
    assert "*100" =~ r
    assert_equal "100", $1
  end
  
  #
  # parse_indicies test
  #
  
  def test_parse_indicies_documentation
    assert_equal [], parse_indicies('')
    assert_equal [1], parse_indicies('1')
    assert_equal [1,2,3], parse_indicies('1,2,3')
  end
  
  def test_parse_indicies_handles_multiple_commas_gracefully
    assert_equal [1,2,3], parse_indicies(',,1,2,,,3,,')
  end
  
  #
  # parse_rounds test
  #
  
  def test_parse_rounds_documentation
    assert_equal [1, [:current_index]], parse_round("+", "")
    assert_equal [2, [1,2,3]], parse_round("+2", "1,2,3")
    assert_equal [0, [:current_index]], parse_round(nil, nil)
  end
  
  def test_parse_rounds
    assert_equal [0, [:current_index]], parse_round("", "")
    assert_equal [1, [:current_index]], parse_round("+", "")
    assert_equal [2, [:current_index]], parse_round("++", "")
  
    assert_equal [0, [:current_index]], parse_round("+0", "")
    assert_equal [1, [:current_index]], parse_round("+1", "")
    assert_equal [2, [:current_index]], parse_round("+2", "")
  
    assert_equal [0, [1,2,3]], parse_round("", "1,2,3")
    assert_equal [0, [:current_index]], parse_round("", nil)
    assert_equal [0, [:current_index]], parse_round(nil, "")
    assert_equal [0, [:current_index]], parse_round(nil, nil)
  end
  
  #
  # parse_sequence test
  #
  
  def test_parse_sequence_documentation
    assert_equal [[1,2,3], {}], parse_sequence("1:2:3", '')
    assert_equal [[:previous_index,1,2,:current_index], {}], parse_sequence(":1:2:", '')
  end
  
  def test_parse_sequence
    assert_equal [[:previous_index,:current_index], {}], parse_sequence(":", '')
    assert_equal [[1,:current_index], {}], parse_sequence("1:", '')
    assert_equal [[:previous_index,2], {}], parse_sequence(":2", '')
    assert_equal [[1,2], {}], parse_sequence("1:2", '')
    assert_equal [[1,2,3], {}], parse_sequence("1:2:3", '')
    assert_equal [[100,200,300], {}], parse_sequence("100:200:300", '')
    assert_equal [[:previous_index,1,2,3,:current_index], {}], parse_sequence(":1:2:3:", '')
  end
  
  #
  # parse_prerequisite test
  #
  
  def test_parse_prerequisite_documentation
    assert_equal 1, parse_prerequisite("1")
    assert_equal :current_index, parse_prerequisite("")
  end
  
  #
  # parse_bracket test
  #
  
  def test_parse_bracket_documentation
    assert_equal [[1], [2,3],{}], parse_bracket("1", "2,3", "")
    assert_equal [[:previous_index], [:current_index],{}], parse_bracket("", "", "")
    assert_equal [[1], [:current_index],{}], parse_bracket("1", "", "")
    assert_equal [[:previous_index], [2,3],{}], parse_bracket("", "2,3", "")
  end
  
  def test_parse_bracket
    assert_equal [[:previous_index], [:current_index],{}], parse_bracket("", "", "")
    assert_equal [[1], [:current_index],{}], parse_bracket("1", "", "")
    assert_equal [[:previous_index], [2],{}], parse_bracket("", "2", "")
    assert_equal [[1], [2],{}], parse_bracket("1", "2", "")
    assert_equal [[1], [2,3],{}], parse_bracket("1", "2,3", "")
    assert_equal [[100], [200,300],{}], parse_bracket("100", "200,300", "")
  end
  
  #
  # parse_reverse_bracket test
  #
  
  def test_parse_reveres_bracket
    assert_equal [[:current_index], [:previous_index], {}], parse_reverse_bracket("", "", "")
    assert_equal [[:current_index], [1], {}], parse_reverse_bracket("1", "", "")
    assert_equal [[2], [:previous_index], {}], parse_reverse_bracket("", "2", "")
    assert_equal [[2], [1], {}], parse_reverse_bracket("1", "2", "")
    assert_equal [[2,3], [1], {}], parse_reverse_bracket("1", "2,3", "")
    assert_equal [[200,300], [100], {}], parse_reverse_bracket("100", "200,300", "")
  end
  
  #
  # parse_options test
  #
  
  def test_parse_options_documentation
    assert_equal({}, parse_options(""))
    assert_equal({:iterate => true, :stack => true}, parse_options("ik"))
  end
  
  def test_parse_options_raises_error_for_unknown_options
    assert_raises(RuntimeError) { parse_options("q") }
  end
  
  #
  # parse_argh test
  #
  
  def test_parse_argh_documentation
    argh = {
      0 => {
        0 => 'a',
        1 => ['b', 'c']},
      1 => 'z'
    }
    assert_equal ['--', 'a', 'b', 'c', '--', 'z'], parse_argh(argh)
    
    argh = {
      '0' => {
        '0' => 'a',
        '1' => ['b', 'c']},
      '1' => ['--:', 'z']
    }
    assert_equal ['--', 'a', 'b', 'c', '--:', 'z'], parse_argh(argh)
  end
  
  def test_parse_argh_adds_breaks
    argh = {
      '0' => ['a', 'b', 'c'], 
      '2' => ['x', 'y', 'z'],
    }
    
    result = parse_argh(argh)
    assert_equal %w{-- a b c -- -- x y z}, result
  end
  
  def test_parse_argh_preserves_breaks
    argh = {
      '0' => ['--', 'a', 'b', 'c'],
      '1' => ['--'], 
      '2' => ['--:', 'x', 'y', 'z'],
      '3' => ['--0:2']
    }
    
    result = parse_argh(argh)
    assert_equal %w{-- a b c -- --: x y z --0:2}, result
  end
  
  def test_parse_argh_collapses_and_compacts_hashes_by_index
    argh = {
      '0' => {
        '0' => ['a', 'b'],
        '1' => ['c'],
        '2' => ['d', 'e', 'f'],
        '10' => [],
        '50' => [nil, nil],
        '100' => ['g'],
        '200' => ['h', nil, 'i', nil, 'j']}
    }
    
    result = parse_argh(argh)
    assert_equal %w{-- a b c d e f g h i j}, result
  end
  
  def test_argh_values_need_not_be_arrays
    argh = {
      '0' => {
        '0' => 'a',
        '1' => 'b',
        '2' => nil,
        '3' => 'c'},

      '2' => nil,
      '3' => 'z'
    }
    
    result = parse_argh(argh)
    assert_equal %w{-- a b c -- -- -- z}, result
  end
end

class ParserTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_subset_test
  
  attr_accessor :parser
  
  def setup
    super
    @parser = Parser.new  
  end

  # helper
  def assert_argvs_equal(expected, parser, msg=nil)
    assert_equal expected, parser.schema.argvs, msg
  end
  
  # helper
  def assert_joins_equal(expected, parser, msg=nil)
    schema = parser.schema
    joins = schema.joins.collect do |join, input_nodes, output_nodes|
      [join.class, join.options, schema.indicies(input_nodes), schema.indicies(output_nodes)]
    end
    
    assert_equal expected, joins, msg
  end
  
  # helper
  def assert_rounds_equal(expected, parser, msg=nil)
    schema = parser.schema
    rounds = schema.rounds.collect do |round|
      schema.indicies(round)
    end
    
    assert_equal expected, rounds, msg
  end
  
  # helper
  def assert_globals_equal(expected, parser, msg=nil)
    schema = parser.schema
    globals = schema.indicies(schema.globals)
    
    assert_equal expected, globals, msg
  end
  
  #
  # documentation test
  #
  
  def test_parse_documentation
    schema = Parser.new("a -- b --+ c -- d -- e --+3[4]").schema
    a, b, c, d, e = schema.nodes
    assert_equal [[a,b,d],[c], nil, [e]], schema.rounds

    schema = Parser.new("a --: b -- c --1:2i").schema
    a, b, c = schema.nodes
    joins = schema.joins.collect do |join, inputs, outputs|
      [join.options, inputs, outputs]
    end
    
    assert_equal [[{},[a],[b]], [{:iterate => true},[b],[c]]], joins

    schema = Parser.new("a -- b --* c").schema
    a, b, c = schema.nodes
    assert_equal [c], schema.globals
  
    schema = Parser.new("a -- b -- c").schema
    assert_equal [["a"], ["b"], ["c"]], schema.argvs
  
    schema = Parser.new("a -. -- b .- -- c").schema
    assert_equal [["a", "--", "b"], ["c"]], schema.argvs
  
    schema = Parser.new("a -- b --- c").schema
    assert_equal [["a"], ["b"]], schema.argvs
  end
  
  #
  # initialize test
  #
  
  def test_parser_initializes_empty_schema_for_empty_argv
    schema = Parser.new.schema
    assert schema.nodes.empty?
  end
  
  #
  # tasks tests
  #

  def test_parser_splits_argv_along_all_breaks_to_get_argvs
    %w{
      -- --+ --++ --+1 --+0[1,2,3]
      --: --1:2 --1:2is
      --[] --1[2] --1[2]is
      --{} --1{2} --1{2}is
      --() --1(2) --1(2)is
      --*  --*1
    }.each do |split|
      parser = Parser.new ["a", "-b", "--c", split, "d", "-e", "--f", split, "x", "-y", "--z"]
      assert_equal [
        ["a", "-b", "--c"],
        ["d", "-e", "--f"],
        ["x", "-y", "--z"]
      ], parser.schema.cleanup.argvs, split
    end
  end
  
  def test_argvs_includes_short_and_long_options
    parser = Parser.new ["a", "-b", "--c", "--", "d", "-e", "--f", "--", "x", "-y", "--z"]
    assert_equal [
      ["a", "-b", "--c"],
      ["d", "-e", "--f"],
      ["x", "-y", "--z"]
    ], parser.schema.argvs
  end
  
  #
  # rounds tests
  #
  
  def test_parser_assigns_tasks_to_rounds_using_plus_syntax
    parser = Parser.new "-- a --+ b --++ c"
    assert_rounds_equal [[0],[1],[2]], parser
  end
  
  def test_parser_assigns_tasks_to_rounds_using_plus_number_syntax
    parser = Parser.new "--+0 a --+1 b --+2 c "
    assert_rounds_equal [[0],[1],[2]], parser
  end
  
  def test_parser_assigns_tasks_to_rounds_with_target_syntax
    parser = Parser.new "--+0[0] a --+0[1] b --+1[2] c"
    assert_rounds_equal [[0,1],[2]], parser
  end
  
  def test_rounds_may_be_reassigned
    parser = Parser.new "-- a -- b -- c --+1[0,1,2]"
    assert_rounds_equal [nil, [0,1,2]], parser
  
    # reverse
    parser = Parser.new "--+1[0,1,2] -- a -- b -- c "
    assert_rounds_equal [[0,1,2]], parser
  end
  
  def test_parser_rounds_are_order_independent
    parser = Parser.new "--+ b --++ c -- a"
    assert_rounds_equal [[2],[0],[1]], parser
  end
  
  def test_first_round_is_assumed_if_left_unstated
    parser = Parser.new "a"
    assert_rounds_equal [[0]], parser
  
    parser = Parser.new "a -- b"
    assert_rounds_equal [[0, 1]], parser
  end
  
  def test_empty_rounds_are_allowed
    parser = Parser.new "--++ a --+++ b --+++++ c"
    assert_rounds_equal [nil, nil, [0],[1], nil, [2]], parser
  end
  
  #
  # sequence test
  #
  
  def test_sequences_breaks_assign_sequences
    parser = Parser.new "a --: b --: c"
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]]
    ], parser
  end
  
  def test_sequences_may_be_reassigned
    parser = Parser.new "a -- b -- c --0:1:2"
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]],
    ], parser
   
    parser = Parser.new "a --: b --: c --1:0:2"
    assert_joins_equal [
      [Join, {}, [0], [2]],
      [Join, {}, [1], [0]],
    ], parser
  
    # now in reverse
    parser = Parser.new "--1:0:2 a --: b --: c "
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]],
    ], parser
  end
   
  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new "a -- b --:100 c --:200"
    assert_joins_equal [
      [Join, {}, [1], [100]],
      [Join, {}, [2], [200]],
    ], parser
  end
   
  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new  "a --100: b --200: c "
    assert_joins_equal [
      [Join, {}, [100], [1]],
      [Join, {}, [200], [2]],
    ], parser
  end
   
  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new  "a --: b --: c "
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]],
    ], parser
  end
   
  #
  # bracketed workflow test
  # (fork, merge, sync_merge)
  
  def bracket_test
    yield(Join, '[', ']')
  end
  
  def reverse_bracket_test
    yield(Join, '{', '}')
    yield(Joins::SyncMerge, '(', ')')
  end
  
  def test_bracketed_workflows_are_parsed
    bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r}"
      assert_joins_equal [
        [type, {}, [1], [2]],
        [type, {}, [3], [4,5]],
      ], parser, type.to_s
    end
    
    reverse_bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r}"
      assert_joins_equal [
        [type, {}, [2], [1]],
        [type, {}, [4,5], [3]],
      ], parser, type.to_s
    end
  end
  
  def test_bracketed_workflows_may_be_reassigned
    bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r} --1#{l}4,5#{r} --3#{l}2#{r}"
      assert_joins_equal [
        [type, {}, [1], [4,5]],
        [type, {}, [3], [2]]
      ], parser, type.to_s
    end
    
    reverse_bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r} --1#{l}4,5#{r} --3#{l}2#{r}"
      assert_joins_equal [
        [type, {}, [2], [3]],
        [type, {}, [4,5], [1]]
      ], parser, type.to_s
    end
  end
  
  def test_bracketed_workflows_uses_the_last_count_if_no_lead_index_is_specified
    bracket_test do |type, l, r|
      parser = Parser.new "a -- b --#{l}100#{r} c --#{l}200,300#{r}"
      assert_joins_equal [
        [type, {}, [1], [100]],
        [type, {}, [2], [200,300]]
      ], parser, type.to_s
    end
    
    reverse_bracket_test do |type, l, r|
      parser = Parser.new "a -- b --#{l}100#{r} c --#{l}200,300#{r}"
      assert_joins_equal [
        [type, {}, [100], [1]],
        [type, {}, [200,300], [2]]
      ], parser, type.to_s
    end
  end
  
  #
  # parse tests
  #
  
  def test_parse
    parser = Parser.new [
      "a", "a1", "a2", "--key", "value", "--another", "another value",
      "--", "b","b1",
      "--", "c",
      "--+2[0,1,2]",
      "--0:1:2"]
    
    assert_argvs_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"]
    ], parser
    
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]]
    ], parser
    
    assert_rounds_equal [nil, nil, [0]], parser
    assert_globals_equal [], parser
  end
  
  def test_schema_cleanup
    parser = Parser.new %w{a -- b -- c --0:1 --1:2}
    parser.schema.cleanup
    
    assert_argvs_equal [["a"],["b"],["c"]], parser
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]]
    ], parser
    
    assert_rounds_equal [[0]], parser
    assert_globals_equal [], parser
  end
  
  def test_parse_splits_string_argv_using_shellwords
    parser = Parser.new "a a1 a2 --key value --another 'another value' -- b b1 -- c --+2[0,1,2] --0:1:2"
   
    assert_argvs_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"]
    ], parser
    
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]]
    ], parser
    
    assert_rounds_equal [nil, nil, [0]], parser
  end
  
  def test_parse_converts_hash_argvs_to_arrays_using_parse_argh
    argh = {
      '0' => {
        '0' => ['a', 'a1', 'a2'],
        '1' => ['--key', 'value', '--another', 'another value']},
      '1' => {
        '0' => ['b', 'b1']},
      '2' => {
        '0' => ['c']},
      '3' => ['--+2[0,1,2]'],
      '4' => ['--0:1:2']
    }
    
    parser = Parser.new(argh)
    assert_argvs_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"]
    ], parser
    
    assert_joins_equal [
      [Join, {}, [0], [1]],
      [Join, {}, [1], [2]]
    ], parser
    
    assert_rounds_equal [nil, nil, [0]], parser
  end
  
  def test_parse_is_non_destructive
    argv = [
      "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
      "b","b1", "--",
      "c", "--",
      "+2[0,1,2]", "--",
      "0:1:2"]
    argv_ref = argv.dup
    
    p = Parser.new argv
    assert_equal argv_ref, argv
  end
  
  def test_parse_does_not_parse_escaped_args
    parser = Parser.new "a -. -- --: --1[2,3] 4{5,6} x y .- z -- b -- c"
    assert_argvs_equal [
      ["a", "--", "--:", "--1[2,3]", "4{5,6}", "x", "y", "z"],
      ["b"],
      ["c"]
    ], parser
  end
  
  def test_parse_stops_at_end_flag
    assert_argvs_equal [["a"], ["b"]], Parser.new("a -- b --- c")
  end
  
  def test_parse_correctly_assigns_join_inputs_and_outputs_for_forward_join
    schema = Parser.new("a -- b --0:1").schema
    assert_equal schema[0].output, schema[1].input
  end
  
  def test_parse_correctly_assigns_join_inputs_and_outputs_for_reverse_join
    schema = Parser.new("a -- b --0{1}").schema
    assert_equal schema[0].input, schema[1].output
  end
  
  #
  # parse! test
  #
  
  def test_parse_bang_is_destructive
    argv = [
      "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
      "b","b1", "--",
      "c", "--",
      "+2[0,1,2]", "--",
      "0:1:2"]
    argv_ref = argv.dup
  
    Parser.new.parse!(argv)
    assert argv.empty?
  end
  
  def test_parse_bang_stops_at_end_flag
    argv = ["a", "--", "b", "---", "c"]
  
    schema = Parser.new.parse! argv
    assert_equal [["a"], ["b"]], schema.argvs
    assert_equal ["c"], argv
  end
  
  #
  # benchmark test
  #
  
  def test_parse_speed
    benchmark_test(20) do |x|
      
      # 10 nodes
      nodes = Array.new(10) {|i| [i.to_s]}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_argvs_equal nodes, Parser.new(argv)
      x.report("1000x10 nodes") {1000.times { Parser.new(argv) } }
      
      nodes = Array.new(10) {|i| [i.to_s] + %w{a b c d e}}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_argvs_equal nodes, Parser.new(argv)
      x.report("1000x10 nodes+5args") {1000.times { Parser.new(argv) } }
      
      ### 100 nodes
      nodes = Array.new(100) {|i| [i.to_s]}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_argvs_equal nodes, Parser.new(argv)
      x.report("100x100 nodes") {100.times { Parser.new(argv) } }
      
      nodes = Array.new(100) {|i| [i.to_s] + %w{a b c d e}}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_argvs_equal nodes, Parser.new(argv)
      x.report("100x100 nodes+5arg") {100.times { Parser.new(argv) } }
    end
  end
end