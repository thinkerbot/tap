require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema'
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
    
    assert "[1,2,3][4,5,6]is.join" =~ r
    assert_equal "1,2,3", $1
    assert_equal "4,5,6", $2
    assert_equal "is", $3
    assert_equal "join", $4
  
    assert "[][]" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "", $3
    assert_equal nil, $4
    
    # join type variations
    assert "[][]." =~ r
    assert_equal "", $4
    
    assert "[][].Nested::Type" =~ r
    assert_equal "Nested::Type", $4
    
    # input/output variations
    assert "[1][2]" =~ r
    assert_equal "1", $1
    assert_equal "2", $2
    
    # non-matching
    assert "1[2]" !~ r
    assert "[1]2" !~ r
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
      [[1], [2],['join', '']],
      [[2], [3],['join', '']]
    ]
    assert_equal expected, parse_sequence("1:2:3", '')
    
    expected = [
      [[:previous_index], [1], ['join', '']],
      [[1], [2], ['join', '']],
      [[2], [:current_index], ['join', '']],
    ]
    assert_equal expected, parse_sequence(":1:2:", '')
  end
  
  def test_parse_sequence
    expected = [[[:previous_index], [:current_index], ['join', '']]]
    assert_equal expected, parse_sequence(":", '')
    
    expected = [[[1], [:current_index], ['join', '']]]
    assert_equal expected, parse_sequence("1:", '')
    
    expected = [[[:previous_index], [2], ['join', '']]]
    assert_equal expected, parse_sequence(":2", '')
    
    expected = [[[1], [2], ['join', '']]]
    assert_equal expected, parse_sequence("1:2", '')
    
    expected = [
      [[1], [2], ['join', '']],
      [[2], [3], ['join', '']]
    ]
    assert_equal expected, parse_sequence("1:2:3", '')
    
    expected = [
      [[100], [200], ['join', '']],
      [[200], [300], ['join', '']]
    ]
    assert_equal expected, parse_sequence("100:200:300", '')
    
    expected = [
      [[:previous_index], [1], ['join', '']],
      [[1], [2], ['join', '']],
      [[2], [3], ['join', '']],
      [[3], [:current_index], ['join', '']],
    ]
    assert_equal expected, parse_sequence(":1:2:3:", '')
  end
  
  #
  # parse_join test
  #
  
  def test_parse_join_documentation
    assert_equal [[1], [2,3], ['join', '']], parse_join("1", "2,3", "", nil)
    assert_equal [[], [], ['type', 'is']], parse_join("", "", "is", "type")
  end
end

class ParserTest < Test::Unit::TestCase
  Parser = Tap::Schema::Parser
  
  attr_accessor :parser
  
  def setup
    super
    @parser = Parser.new  
  end

  # helper
  def assert_nodes_equal(expected, parser, msg=nil)
    actual = parser.schema.nodes.collect {|node| node.metadata }
    assert_equal expected, actual, msg
  end
  
  # helper
  def assert_joins_equal(expected, parser, msg=nil)
    schema = parser.schema
    joins = schema.joins.collect do |join|
      [schema.indicies(join.inputs), schema.indicies(join.outputs), join.metadata]
    end
    
    assert_equal expected, joins, msg
  end
  
  #
  # documentation test
  #
  
  def test_parse_documentation
    schema = Parser.new("a -- b --: c").schema
    expected = [["a"], ["b"], ["c"]]
    assert_equal expected, schema.nodes.collect {|node| node.metadata }
  
    a,b,c = schema.nodes
    assert_equal nil, a.output
    assert_equal Tap::Schema::Join, b.output.class
    assert_equal true, (b.output == c.input)
    
    schema = Parser.new("a -- b -- c --0:1 --1:2").schema
    a,b,c = schema.nodes
    assert_equal true, (a.output == b.input)
    assert_equal true, (b.output == c.input)
  
    schema = Parser.new("a --1:2 --0:1 b -- c").schema
    a,b,c = schema.nodes
    assert_equal true, (a.output == b.input)
    assert_equal true, (b.output == c.input)
  
    schema = Parser.new("a -- b -- c").schema
    assert_equal [["a"], ["b"], ["c"]], schema.metadata
  
    schema = Parser.new("a -. -- b .- -- c").schema
    assert_equal [["a", "--", "b"], ["c"]], schema.metadata
  
    schema = Parser.new("a -- b --- c").schema
    assert_equal [["a"], ["b"]], schema.metadata
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
      --
      --: --1:2 --1:2is
      --[1][2] --[1,2][3,4]is.type
    }.each do |split|
      parser = Parser.new ["a", "-b", "--c", split, "d", "-e", "--f", split, "x", "-y", "--z"]
      assert_equal [
        ["a", "-b", "--c"],
        ["d", "-e", "--f"],
        ["x", "-y", "--z"]
      ], parser.schema.cleanup.metadata, split
    end
  end
  
  def test_argvs_includes_short_and_long_options
    parser = Parser.new ["a", "-b", "--c", "--", "d", "-e", "--f", "--", "x", "-y", "--z"]
    assert_equal [
      ["a", "-b", "--c"],
      ["d", "-e", "--f"],
      ["x", "-y", "--z"]
    ], parser.schema.cleanup.metadata
  end
  
  #
  # sequence test
  #
  
  def test_sequences_breaks_assign_sequences
    parser = Parser.new "a --: b --: c"
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']]
    ], parser
  end
  
  def test_sequences_may_be_reassigned
    parser = Parser.new "a -- b -- c --0:1:2"
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']],
    ], parser
   
    parser = Parser.new "a --: b --: c --1:0:2"
    assert_joins_equal [
      [[0], [2], ['join', '']],
      [[1], [0], ['join', '']],
    ], parser
  
    # now in reverse
    parser = Parser.new "--1:0:2 a --: b --: c "
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']],
    ], parser
  end
   
  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new "a -- b --:100 c --:200"
    assert_joins_equal [
      [[1], [100], ['join', '']],
      [[2], [200], ['join', '']],
    ], parser
  end
   
  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new  "a --100: b --200: c "
    assert_joins_equal [
      [[100], [1], ['join', '']],
      [[200], [2], ['join', '']],
    ], parser
  end
   
  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new  "a --: b --: c "
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']],
    ], parser
  end
   
  #
  # join test
  # (fork, merge, sync_merge)
  
  def test_joins_are_parsed
    parser = Parser.new "--[1][2] --[3][4,5]"
    assert_joins_equal [
      [[1], [2], ['join', '']],
      [[3], [4,5], ['join', '']],
    ], parser
  end
  
  def test_joins_may_be_reassigned
    parser = Parser.new "--[1][2] --[3][4,5] --[1][4,5] --[3][2]"
    assert_joins_equal [
      [[1], [4,5], ['join', '']],
      [[3], [2], ['join', '']]
    ], parser
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
    
    assert_nodes_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"]
    ], parser
    
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']]
    ], parser
  end
  
  def test_schema_cleanup
    parser = Parser.new %w{a -- b -- c --0:1 --1:2}
    parser.schema.cleanup
    
    assert_nodes_equal [["a"],["b"],["c"]], parser
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']]
    ], parser
  end
  
  def test_parse_splits_string_argv_using_shellwords
    parser = Parser.new "a a1 a2 --key value --another 'another value' -- b b1 -- c --0:1:2"
   
    assert_nodes_equal [
      ["a", "a1", "a2", "--key", "value", "--another", "another value"],
      ["b", "b1"],
      ["c"]
    ], parser
    
    assert_joins_equal [
      [[0], [1], ['join', '']],
      [[1], [2], ['join', '']]
    ], parser
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
    assert_nodes_equal [
      ["a", "--", "--:", "--1[2,3]", "4{5,6}", "x", "y", "z"],
      ["b"],
      ["c"]
    ], parser
  end
  
  def test_parse_stops_at_end_flag
    assert_nodes_equal [["a"], ["b"]], Parser.new("a -- b --- c")
  end
  
  def test_parse_correctly_assigns_join_inputs_and_outputs_for_sequence
    schema = Parser.new("a -- b --0:1").schema
    assert_equal schema[0].output, schema[1].input
  end
  
  def test_parse_correctly_assigns_join_inputs_and_outputs_for_join
    schema = Parser.new("a -- b --[0][1]").schema
    assert_equal schema[0].output, schema[1].input
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
    assert_equal [["a"], ["b"]], schema.metadata
    assert_equal ["c"], argv
  end
end