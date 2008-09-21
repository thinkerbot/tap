require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/parser'
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
  # INSTANCE test
  #
  
  def test_INSTANCE_regexp
    r = INSTANCE
    
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
  # parse_instance test
  #
  
  def test_parse_instance_documentation
    assert_equal 1, parse_instance("1")
    assert_equal :current_index, parse_instance("")
  end
  
  #
  # parse_bracket test
  #
  
  def test_parse_bracket_documentation
    assert_equal [1, [2,3],{}], parse_bracket("1", "2,3", "")
    assert_equal [:previous_index, [:current_index],{}], parse_bracket("", "", "")
    assert_equal [1, [:current_index],{}], parse_bracket("1", "", "")
    assert_equal [:previous_index, [2,3],{}], parse_bracket("", "2,3", "")
  end
  
  def test_parse_bracket
    assert_equal [:previous_index, [:current_index],{}], parse_bracket("", "", "")
    assert_equal [1, [:current_index],{}], parse_bracket("1", "", "")
    assert_equal [:previous_index, [2],{}], parse_bracket("", "2", "")
    assert_equal [1, [2],{}], parse_bracket("1", "2", "")
    assert_equal [1, [2,3],{}], parse_bracket("1", "2,3", "")
    assert_equal [100, [200,300],{}], parse_bracket("100", "200,300", "")
  end
  
  #
  # parse_options test
  #
  
  def test_parse_options_documentation
    assert_equal({}, parse_options(""))
    assert_equal({:iterate => true, :stack => true}, parse_options("is"))
  end
  
  def test_parse_options
    assert_equal({}, parse_options(""))
    assert_equal({:iterate => true, :stack => true}, parse_options("is"))
  end
  
  def test_parse_options_raises_error_for_unknown_options
    assert_raise(RuntimeError) { parse_options("q") }
  end
end

class ParserTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :parser
  
  def setup
    @parser = Parser.new  
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
      ], parser.schema.compact.argvs, split
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
    assert_equal [[0],[1],[2]], parser.schema.rounds(true)
  end
  
  def test_parser_assigns_tasks_to_rounds_using_plus_number_syntax
    parser = Parser.new "--+0 a --+1 b --+2 c "
    assert_equal [[0],[1],[2]], parser.schema.rounds(true)
  end
  
  def test_parser_assigns_tasks_to_rounds_with_target_syntax
    parser = Parser.new "--+0[0] a --+0[1] b --+1[2] c"
    assert_equal [[0,1],[2]], parser.schema.rounds(true)
  end
  
  def test_rounds_may_be_reassigned
    parser = Parser.new "-- a -- b -- c --+1[0,1,2]"
    assert_equal [nil, [0,1,2]], parser.schema.rounds(true)
  
    # reverse
    parser = Parser.new "--+1[0,1,2] -- a -- b -- c "
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  end
  
  def test_parser_rounds_are_order_independent
    parser = Parser.new "--+ b --++ c -- a"
    assert_equal [[2],[0],[1]], parser.schema.rounds(true)
  end
  
  def test_first_round_is_assumed_if_left_unstated
    parser = Parser.new "a"
    assert_equal [[0]], parser.schema.rounds(true)
  
    parser = Parser.new "a -- b"
    assert_equal [[0, 1]], parser.schema.rounds(true)
  end
  
  def test_empty_rounds_are_allowed
    parser = Parser.new "--++ a --+++ b --+++++ c"
    assert_equal [nil, nil, [0],[1], nil, [2]], parser.schema.rounds(true)
  end
  
  #
  # sequence test
  #
  
  def test_sequences_breaks_assign_sequences
    parser = Parser.new "a --: b --: c"
    assert_equal([
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}]
    ], parser.schema.joins(true))
  end
  
  def test_sequences_may_be_reassigned
    parser = Parser.new "a -- b -- c --0:1:2"
    assert_equal([
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}],
    ], parser.schema.joins(true))
   
    parser = Parser.new "a --: b --: c --1:0:2"
    assert_equal([
      [:sequence, nil, [1], {}],  # unassigned join
      [:sequence, 0, [2], {}],
      [:sequence, 1, [0], {}],
    ], parser.schema.joins(true))

    # now in reverse
    parser = Parser.new "--1:0:2 a --: b --: c "
    assert_equal([
      [:sequence, nil, [0], {}],  # unassigned join
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}],
    ], parser.schema.joins(true))
  end
   
  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new "a -- b --:100 c --:200"
    assert_equal([
      [:sequence, 1, [100], {}],
      [:sequence, 2, [200], {}],
    ], parser.schema.joins(true))
  end
   
  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new  "a --100: b --200: c "
    assert_equal([
      [:sequence, 100, [1], {}],
      [:sequence, 200, [2], {}],
    ], parser.schema.joins(true))
  end
   
  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new  "a --: b --: c "
    assert_equal([
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}],
    ], parser.schema.joins(true))
  end
   
  #
  # bracketed workflow test
  # (fork, merge, sync_merge)
  
  def bracket_test
    yield(:fork, '[', ']')
    yield(:merge, '{', '}')
    yield(:sync_merge, '(', ')')
  end
  
  def test_bracketed_workflows_are_parsed
    bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r}"
      assert_equal([
        [type, 1, [2], {}],
        [type, 3, [4,5], {}],
      ], parser.schema.joins(true), type)
    end
  end
  
  def test_bracketed_workflows_may_be_reassigned
    bracket_test do |type, l, r|
      parser = Parser.new "--1#{l}2#{r} --3#{l}4,5#{r} --1#{l}4,5#{r} --3#{l}2#{r}"
      assert_equal([
        [type, 1, [4,5], {}],
        [type, 3, [2], {}]
      ], parser.schema.joins(true), type)
    end
  end
  
  def test_bracketed_workflows_uses_the_last_count_if_no_lead_index_is_specified
    bracket_test do |type, l, r|
      parser = Parser.new "a -- b --#{l}100#{r} c --#{l}200,300#{r}"
      assert_equal([
        [type, 1, [100], {}],
        [type, 2, [200,300], {}]
      ], parser.schema.joins(true), type)
    end
  end
  
  #
  # parse tests
  #
  
  def test_parse_documentation
    schema = Parser.new("a -- b --+ c -- d -- e --+3[4]").schema
    assert_equal [[0,1,3],[2], nil, [4]], schema.rounds(true)

    schema = Parser.new("a --: b -- c --1:2i").schema
    assert_equal [["a"], ["b"], ["c"], []], schema.argvs
    assert_equal [[:sequence,0,[1],{}], [:sequence,1,[2],{:iterate => true}]], schema.joins(true)
  
    schema = Parser.new("a -- b --* global_name --config for --global").schema
    assert_equal [2], schema.globals(true)
  
    schema = Parser.new("a -- b -- c").schema
    assert_equal [["a"], ["b"], ["c"]], schema.argvs
  
    schema = Parser.new("a -. -- b .- -- c").schema
    assert_equal [["a", "--", "b"], ["c"]], schema.argvs
  
    schema = Parser.new("a -- b --- c").schema
    assert_equal [["a"], ["b"]], schema.argvs
  end
  
  def test_parse
    schema = Parser.new([
      "a", "a1", "a2", "--key", "value", "--another", "another value",
      "--", "b","b1",
      "--", "c",
      "--+2[0,1,2]",
      "--0:1:2"]).schema
    
    assert_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"],
      []
    ], schema.argvs
    
    assert_equal [nil, nil, [0]], schema.rounds(true)
    assert_equal [
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}]
    ], schema.joins(true)
  end
  
  def test_parse_splits_string_argv_using_shellwords
    schema = Parser.new("a a1 a2 --key value --another 'another value' -- b b1 -- c --+2[0,1,2] --0:1:2").schema
    assert_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"],
      []
    ], schema.argvs
    
    assert_equal [nil, nil, [0]], schema.rounds(true)
    assert_equal [
      [:sequence, 0, [1], {}],
      [:sequence, 1, [2], {}]
    ], schema.joins(true)
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
    schema = Parser.new("a -. -- --: --1[2,3] 4{5,6} x y .- z -- b -- c").schema
    assert_equal [
      ["a", "--", "--:", "--1[2,3]", "4{5,6}", "x", "y", "z"],
      ["b"],
      ["c"]
    ], schema.argvs
  end
  
  def test_parse_stops_at_end_flag
    schema = Parser.new("a -- b --- c").schema
    assert_equal [["a"], ["b"]], schema.argvs
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
  
end