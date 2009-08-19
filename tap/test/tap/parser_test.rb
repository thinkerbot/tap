require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/parser'

class ParserTest < Test::Unit::TestCase
  Parser = Tap::Parser
  
  attr_accessor :parser
  
  def setup
    super
    @parser = Parser.new  
  end
  
  #
  # BREAK test
  #
  
  def test_BREAK_regexp
    r = Parser::BREAK
    
    # break
    assert "--" =~ r
    assert_equal nil, $1
    
    # sequence join
    assert "--:" =~ r
    assert_equal ":", $1
    
    assert "--:is" =~ r
    assert_equal ":is", $1
    
    # general join
    assert "--[]" =~ r
    assert_equal "[]", $1
        
    assert "--[1,2][3,4]is.join" =~ r
    assert_equal "[1,2][3,4]is.join", $1
    
    # enq
    assert "--@" =~ r
    assert_equal "@", $1
    
    # init
    assert "--." =~ r
    assert_equal ".", $1
    
    # signal
    assert "--/var" =~ r
    assert_equal "/var", $1
    
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
    r = Parser::SEQUENCE
    
    assert ":" =~ r
    assert_equal nil, $1
  
    assert ":i" =~ r
    assert_equal "i", $1
    
    assert ":is.join" =~ r
    assert_equal "is.join", $1
  end
  
  #
  # JOIN test
  #
  
  def test_JOIN_regexp
    r = Parser::JOIN

    assert "[][]" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal nil, $3
    
    assert "[1,2,3][4,5,6]is.join" =~ r
    assert_equal "1,2,3", $1
    assert_equal "4,5,6", $2
    assert_equal "is.join", $3
    
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
    r = Parser::JOIN_MODIFIER
    
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
  # SIGNAL test
  #
  
  def test_SIGNAL_regexp
    r = Parser::SIGNAL
    
    assert "/var" =~ r
    assert_equal "var", $1
    
    assert "/" =~ r
    assert_equal nil, $1
    
    # non-matching
    assert "str" !~ r
  end
  
  #
  # parse test
  #
  
  def test_parse_parses_task_and_enque_along_option_break
    parser.parse %w{-- a b c -- x y z}
    assert_equal [
      ["0", "task", "a", "b", "c"],
      ["1", "task", "x", "y", "z"]
    ], parser.specs
  end
  
  def test_parse_unshifts_option_break_if_argv_does_not_start_with_a_break
    parser.parse %w{a b c}
    assert_equal [
      ["0", "task", "a", "b", "c"],
    ], parser.specs
  end
  
  def test_parse_allows_options_in_tasks
    parser.parse %w{-- a -b --c}
    assert_equal [
      ["0", "task", "a", "-b", "--c"],
    ], parser.specs
  end
  
  def test_parse_incrementes_index_but_does_not_add_tasks_for_empty_breaks
    parser.parse %w{-- a -- -- -- b --}
    assert_equal [
      ["0", "task", "a"],
      ["3", "task", "b"]
    ], parser.specs
  end
  
  def test_parse_is_non_destructive
    argv = %w{-- a b c}
    assert_equal [], parser.parse(argv)
    assert_equal %w{-- a b c}, argv
  end
  
  def test_parse_does_not_parse_escaped_args
    parser.parse %w{-- a -. -- --: -z- .- b -- c}
    assert_equal [
      ["0", "task", "a", "--", "--:", "-z-", "b"],
      ["1", "task", "c"]
    ], parser.specs
  end
  
  def test_parse_stops_at_end_flag
    parser.parse %w{-- a --- -- b}
    assert_equal [
      ["0", "task", "a"]
    ], parser.specs
  end
  
  def test_parse_returns_remaining_args
    assert_equal [], parser.parse(%w{-- a -- b})
    assert_equal ["b"], parser.parse(%w{-- a --- b})
  end
  
  def test_parse_splits_string_to_argv
    assert_equal ['c'], parser.parse("a -- b --- c")
    assert_equal [
      ["0", "task", "a"],
      ["1", "task", "b"]
    ], parser.specs
  end
  
  def test_parse_resets_counter_and_appends_specs_for_each_call
    parser.parse %w{-- a b c}
    parser.parse %w{-- x y z}
    assert_equal [
      ["0", "task", "a", "b", "c"],
      ["0", "task", "x", "y", "z"]
    ], parser.specs
  end
  
  def test_parse_raises_error_for_invalid_breaks
    err = assert_raises(RuntimeError) { parser.parse "--[]" }
    assert_equal "invalid break: --[] (invalid modifier)", err.message
    
    err = assert_raises(RuntimeError) { parser.parse "--[][]123" }
    assert_equal "invalid break: --[][]123 (invalid join modifier)", err.message
  end
  
  #
  # parse! test
  #
  
  def test_parse_bang_is_destructive
    argv = %w{-- a b c}
    assert_equal [], parser.parse!(argv)
    assert_equal [], argv
  end
  
  #
  # sequence test
  #
  
  def test_sequence_breaks_assign_sequence_joins
    parser.parse "-- a --: b --: c"
    assert_equal [
      ["0", "task", "a"],
      ["1", "task", "b"],
      [nil, "join", "join", "0", "1"],
      ["2", "task", "c"],
      [nil, "join", "join", "1", "2"]
    ], parser.specs
  end
  
  def test_sequence_with_modifier
    parser.parse  "-- a --:is.class b"
    assert_equal [
      ["0", "task", "a"],
      ["1", "task", "b"],
      [nil, "join", "class", "0", "1", "-i", "-s"],
    ], parser.specs
  end
  
  #
  # join test
  # 
  
  def test_parser_parses_joins
    parser.parse "--[1][2] --[1][2,3]"
    assert_equal [
      [nil, "join", "join", "1", "2"],
      [nil, "join", "join", "1", "2,3"]
    ], parser.specs
  end
  
  def test_join_does_not_infer_lead_or_end_index
    parser.parse "--[][] --[1][] --[][2]"
    assert_equal [
      [nil, "join", "join", "", ""],
      [nil, "join", "join", "1", ""],
      [nil, "join", "join", "", "2"]
    ], parser.specs
  end
  
  def test_join_with_modifier
    parser.parse  "--[][]is.class"
    assert_equal [
      [nil, "join", "class", "", "", "-i", "-s"]
    ], parser.specs
  end
  
  #
  # signal tests
  #
  
  def test_parser_parses_signals
    parser.parse  "--/variable signal a b c"
    assert_equal [
      ["variable", nil, "signal", "a", "b", "c"]
    ], parser.specs
  end
  
  #
  # spec tests
  #
  
  def test_parser_parses_spec
    parser.parse  "--. type class a b c"
    assert_equal [
      ["0", "type", "class", "a", "b", "c"]
    ], parser.specs
  end
  
  #
  # job tests
  #
  
  def test_parser_parses_job
    parser.parse  "--@ a b c"
    assert_equal [
      [nil, nil, "enque", "a", "b", "c"]
    ], parser.specs
  end
end