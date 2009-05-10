require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema/parser'
require 'yaml'

class ParserUtilsTest < Test::Unit::TestCase
  include Tap::Schema::Parser::Utils

  def previous_index
    :previous_index
  end

  def current_index
    :current_index
  end
  
  #
  # BREAK test
  #
  
  def test_BREAK_regexp
    r = BREAK
    
    assert "--" =~ r
    assert_equal "", $1
    
    assert "--:" =~ r
    assert_equal ":", $1
    
    assert "--1:2:3" =~ r
    assert_equal "1:2:3", $1
    
    assert "--[]" =~ r
    assert_equal "[]", $1
    
    assert "--[1][2]" =~ r
    assert_equal "[1][2]", $1

    assert "--1[2,3]" =~ r
    assert_equal "1[2,3]", $1
    
    assert "--[1,2]3" =~ r
    assert_equal "[1,2]3", $1
    
    assert "--[1,2][3,4]s.join" =~ r
    assert_equal "[1,2][3,4]s.join", $1
    
    # non-matching
    assert "goodnight" !~ r
    assert "moon" !~ r
    assert "8" !~ r
    
    assert "-" !~ r
    assert " -- " !~ r
    assert "-- " !~ r
    assert " --" !~ r
    
    assert "-o" !~ r
    assert "-opt" !~ r
    assert "--opt" !~ r
    assert "--no-opt" !~ r
    
    # escapes
    assert "---" !~ r
    assert "-." !~ r
    assert ".-" !~ r
  end

  #
  # SEQUENCE test
  #
  
  def test_SEQUENCE_regexp
    r = SEQUENCE
    
    assert ":" =~ r
    assert_equal ":", $1
    assert_equal "", $2
    
    assert "1:2" =~ r
    assert_equal "1:2", $1
    assert_equal "", $2
    
    assert "1:" =~ r
    assert_equal "1:", $1
    assert_equal "", $2
    
    assert ":2" =~ r
    assert_equal ":2", $1
    assert_equal "", $2
    
    assert "100:200" =~ r
    assert_equal "100:200", $1
    assert_equal "", $2
    
    assert "1:2:3" =~ r
    assert_equal "1:2:3", $1
    assert_equal "", $2
  
    assert ":i" =~ r
    assert_equal ":", $1
    assert_equal "i", $2
    
    assert "1:2is" =~ r
    assert_equal "1:2", $1
    assert_equal "is", $2
    
    # non-matching
    assert "--1" !~ r
    assert "-- 1 : 2" !~ r
    assert "1" !~ r
    assert "--i" !~ r
  end
  
  #
  # JOIN test
  #
  
  def test_JOIN_regexp
    r = JOIN
    
    assert "[1,2,3][4,5,6] join -i -s" =~ r
    assert_equal "1,2,3", $1
    assert_equal "4,5,6", $2
    assert_equal " join -i -s", $3

    assert "[1,2,3][4,5,6]is.join" =~ r
    assert_equal "1,2,3", $1
    assert_equal "4,5,6", $2
    assert_equal "is.join", $3
  
    assert "[][]" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "", $3
    
    # input/output variations
    assert "[1][2]" =~ r
    assert_equal "1", $1
    assert_equal "2", $2
    
    # non-matching
    assert "1[2]" !~ r
    assert "[1]2" !~ r
  end
  
  #
  # JOIN_MODIFIER test
  #
  
  def test_JOIN_MODIFIER_regexp
    r = JOIN_MODIFIER
    
    assert "i" =~ r
    assert_equal "i", $1
    assert_equal nil, $2
    
    assert "is" =~ r
    assert_equal "is", $1
    assert_equal nil, $2
    
    assert "is.sync" =~ r
    assert_equal "is", $1
    assert_equal "sync", $2
    
    assert ".sync" =~ r
    assert_equal "", $1
    assert_equal "sync", $2
    
    assert "A.sync" =~ r
    assert_equal "A", $1
    assert_equal "sync", $2
    
    assert "is." =~ r
    assert_equal "is", $1
    assert_equal "", $2
    
    # non-matching cases
    assert " join -i -s" !~ r
    assert " " !~ r
    assert "1" !~ r
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
  # parse_sequence test
  #
  
  def test_parse_sequence_documentation
    expected = [
      ['join', [1], [2]],
      ['join', [2], [3]]
    ]
    assert_equal expected, parse_sequence("1:2:3", '')
    
    expected = [
      ['join', [:previous_index], [1], '-i', '-s'],
      ['join', [1], [2], '-i', '-s'],
      ['join', [2], [:current_index], '-i', '-s'],
    ]
    assert_equal expected, parse_sequence(":1:2:", 'is')
  end
  
  def test_parse_sequence
    expected = [['join', [:previous_index], [:current_index]]]
    assert_equal expected, parse_sequence(":", '')
    
    expected = [['join', [1], [:current_index]]]
    assert_equal expected, parse_sequence("1:", '')
    
    expected = [['join', [:previous_index], [2]]]
    assert_equal expected, parse_sequence(":2", '')
    
    expected = [['join', [1], [2]]]
    assert_equal expected, parse_sequence("1:2", '')
    
    expected = [
      ['join', [1], [2]],
      ['join', [2], [3]]
    ]
    assert_equal expected, parse_sequence("1:2:3", '')
    
    expected = [
      ['join', [100], [200]],
      ['join', [200], [300]]
    ]
    assert_equal expected, parse_sequence("100:200:300", '')
    
    expected = [
      ['join', [:previous_index], [1]],
      ['join', [1], [2]],
      ['join', [2], [3]],
      ['join', [3], [:current_index]],
    ]
    assert_equal expected, parse_sequence(":1:2:3:", '')
  end
  
  #
  # parse_join test
  #
  
  def test_parse_join_documentation
    assert_equal ['join', [1], [2,3]], parse_join("1", "2,3", "")
    assert_equal ['type', [], [], '-i', '-s'], parse_join("", "", "is.type")
    assert_equal ['type', [], [], '-i', '-s'], parse_join("", "", "type -i -s")
  end
end

class ParserTest < Test::Unit::TestCase
  Parser = Tap::Schema::Parser
  
  attr_accessor :parser
  
  def setup
    super
    @parser = Parser.new  
  end
  
  #
  # documentation test
  #
  
  def test_parse_documentation
    schema = Parser.new("a -- b --: c").schema
    assert_equal({0 => ["a"], 1 => ["b"], 2 => ["c"]}, schema.tasks)
    assert_equal [['join', [1],[2]]], schema.joins
    assert_equal [0,1], schema.queue
    
    schema = Parser.new("a -- b -- c --0:1 --1:2").schema
    assert_equal({0 => ["a"], 1 => ["b"], 2 => ["c"]}, schema.tasks)
    assert_equal [
      ['join', [0],[1]],
      ['join', [1],[2]]
    ], schema.joins
  
    schema = Parser.new("a --1:2 --0:1 b -- c").schema
    assert_equal({0 => ["a"], 1 => ["b"], 2 => ["c"]}, schema.tasks)
    assert_equal [
      ['join', [1],[2]],
      ['join', [0],[1]]
    ], schema.joins
  
    schema = Parser.new("a -- b -- c").schema
    assert_equal({0 => ["a"], 1 => ["b"], 2 => ["c"]}, schema.tasks)
  
    schema = Parser.new("a -. -- b .- -- c").schema
    assert_equal({0 => ["a", "--", "b"], 1 => ["c"]}, schema.tasks)
  
    schema = Parser.new("a -- b --- c").schema
    assert_equal({0 => ["a"], 1 => ["b"]}, schema.tasks)
  end
  
  #
  # initialize test
  #
  
  def test_parser_initializes_empty_schema_for_empty_argv
    schema = Parser.new.schema
    assert schema.tasks.empty?
  end
  
  #
  # tasks tests
  #
  
  def test_parser_splits_argv_along_all_breaks_to_get_argvs
    %w{
      --
      --: --1:2 --1:2is
      --[1][2] --[1,2][3,4]is.type
    }.each do |split|
      parser = Parser.new ["a", "-b", "--c", split, "d", "-e", "--f", split, "x", "-y", "--z"]
      assert_equal({
        0 => ["a", "-b", "--c"],
        1 => ["d", "-e", "--f"],
        2 => ["x", "-y", "--z"]
      }, parser.schema.tasks, split)
    end
  end
  
  def test_argvs_includes_short_and_long_options
    parser = Parser.new ["a", "-b", "--c", "--", "d", "-e", "--f", "--", "x", "-y", "--z"]
    assert_equal({
      0 => ["a", "-b", "--c"],
      1 => ["d", "-e", "--f"],
      2 => ["x", "-y", "--z"]
    }, parser.schema.tasks)
  end
  
  #
  # sequence test
  #
  
  def test_sequences_breaks_assign_sequences
    parser = Parser.new "a --: b --: c"
    assert_equal [
      ['join', [0], [1]],
      ['join', [1], [2]]
    ], parser.schema.joins
  end
  
  def test_sequences_removes_targets_from_queue
    parser = Parser.new "a --: b --: c"
    assert_equal [0], parser.schema.queue
  end
   
  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new "a -- b --:100 c --:200"
    assert_equal [
      ['join', [1], [100]],
      ['join', [2], [200]],
    ], parser.schema.joins
  end
   
  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new  "a --100: b --200: c "
    assert_equal [
      ['join', [100], [1]],
      ['join', [200], [2]],
    ], parser.schema.joins
  end
   
  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new  "a --: b --: c "
    assert_equal [
      ['join', [0], [1]],
      ['join', [1], [2]],
    ], parser.schema.joins
  end
   
  #
  # join test
  # (fork, merge, sync_merge)
  
  def test_joins_are_parsed
    parser = Parser.new "--[1][2] --[3][4,5]"
    assert_equal [
      ['join', [1], [2]],
      ['join', [3], [4,5]],
    ], parser.schema.joins
  end
  
  def test_join_targets_are_removed_from_queue
    parser = Parser.new "-- a -- b -- c -- d -- e --[1][2] --[3][4,5]"
    assert_equal [0,1,3], parser.schema.queue
  end
  
  #
  # parse tests
  #
  
  def test_parse
    parser = Parser.new [
      "a", "a1", "a2", "--key", "value", "--another", "another value",
      "--", "b","b1",
      "--", "c",
      "--0:1:2"]
    schema = parser.schema
    
    assert_equal({
      0 => ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      1 => ["b", "b1"],
      2 => ["c"]
    }, schema.tasks)
    
    assert_equal [
      ['join', [0], [1]],
      ['join', [1], [2]]
    ], schema.joins
  end
  
  def test_parse_splits_string_argv_using_shellwords
    parser = Parser.new "a a1 a2 --key value --another 'another value' -- b b1 -- c --0:1:2"
    schema = parser.schema
    
    assert_equal({
      0 => ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      1 => ["b", "b1"],
      2 => ["c"]
    }, schema.tasks)
    
    assert_equal [
      ['join', [0], [1]],
      ['join', [1], [2]]
    ], schema.joins
  end
  
  def test_parse_splits_join_argv_using_shellwords
    parser = Parser.new %q{a '--: b "c e" f' g}
    schema = parser.schema
    
    assert_equal [
      ['b', [0], [1], 'c e', 'f'],
    ], schema.joins
  end
  
  def test_parse_is_non_destructive
    argv = [
      "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
      "b","b1", "--",
      "c", "--",
      "0:1:2"]
    argv_ref = argv.dup
    
    p = Parser.new argv
    assert_equal argv_ref, argv
  end
  
  def test_parse_does_not_parse_escaped_args
    parser = Parser.new "a -. -- --: --1[2,3] 4{5,6} x y .- z -- b -- c"
    assert_equal({
      0 => ["a", "--", "--:", "--1[2,3]", "4{5,6}", "x", "y", "z"],
      1 => ["b"],
      2 => ["c"]
    }, parser.schema.tasks)
  end
  
  def test_parse_stops_at_end_flag
    assert_equal({0 => ["a"], 1 => ["b"]}, Parser.new("a -- b --- c").schema.tasks)
  end

  #
  # parse! test
  #
  
  def test_parse_bang_is_destructive
    argv = [
      "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
      "b","b1", "--",
      "c", "--",
      "0:1:2"]
    argv_ref = argv.dup
  
    Parser.new.parse!(argv)
    assert argv.empty?
  end
  
  def test_parse_bang_stops_at_end_flag
    argv = ["a", "--", "b", "---", "c"]
  
    schema = Parser.new.parse! argv
    assert_equal({0 => ["a"], 1 => ["b"]}, schema.tasks)
    assert_equal ["c"], argv
  end
end