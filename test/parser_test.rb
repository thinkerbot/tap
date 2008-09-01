require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/parser'


class ParserUtilsTest < Test::Unit::TestCase
  include Tap::Parser::Utils
  
  def next_index
    :next_index
  end
  
  def current_index
    :current_index
  end
  
  #
  # parse_yaml tests
  #
  
  def test_parse_yaml_documentation
    str = {'key' => 'value'}.to_yaml
    assert_equal "--- \nkey: value\n", str
    assert_equal({'key' => 'value'}, parse_yaml(str))
    assert_equal "str", parse_yaml("str")
  end
  
  def test_parse_yaml_loads_arg_if_arg_matches_yaml_document_string
    string = "---\nkey: value"
    assert_equal({"key" => "value"}, parse_yaml(string))
  end
  
  def test_parse_yaml_returns_arg_unless_matches_yaml_document_string
    string = "key: value"
    assert_equal("key: value", parse_yaml(string))
  end
  
  #
  # bracket_regexp test
  #
  
  def test_bracket_regexp
    r = bracket_regexp("[", "]")
    
    assert "--[]" =~ r
    assert_equal "", $2
    assert_equal "", $3
    
    assert "--1[]" =~ r
    assert_equal "1", $2
    assert_equal "", $3
    
    assert "--[2]" =~ r
    assert_equal "", $2
    assert_equal "2", $3
    
    assert "--1[2]" =~ r
    assert_equal "1", $2
    assert_equal "2", $3
    
    assert "--1[2,3,4]" =~ r
    assert_equal "1", $2
    assert_equal "2,3,4", $3
  
    assert "--100[200,300,400]" =~ r
    assert_equal "100", $2
    assert_equal "200,300,400", $3

    # same without option break
    assert "[]" =~ r
    assert_equal "", $2
    assert_equal "", $3
    
    assert "1[]" =~ r
    assert_equal "1", $2
    assert_equal "", $3
    
    assert "[2]" =~ r
    assert_equal "", $2
    assert_equal "2", $3
    
    assert "1[2]" =~ r
    assert_equal "1", $2
    assert_equal "2", $3
    
    assert "1[2,3,4]" =~ r
    assert_equal "1", $2
    assert_equal "2,3,4", $3
  
    assert "100[200,300,400]" =~ r
    assert_equal "100", $2
    assert_equal "200,300,400", $3

    # non-matching
    assert "--1" !~ r
    assert "--1[2, 3, 4]" !~ r
    assert "1" !~ r
  end
  
  #
  # BREAK test
  #
  
  def test_BREAK_regexp
    r = BREAK
    
    assert "--" =~ r
    assert "--+" =~ r
    assert "--:" =~ r
    assert "--1" =~ r
    assert "--[" =~ r
    assert "--(" =~ r
    assert "--{" =~ r
    assert "--*" =~ r
    
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
  # WORKFLOW test
  #
  
  def test_WORKFLOW_regexp
    r = WORKFLOW
    
    assert "+" =~ r
    assert ":" =~ r
    assert "1" =~ r
    assert "[" =~ r
    assert "{" =~ r
    assert "(" =~ r
    assert "*" =~ r
  end
  
  #
  # ROUND test
  #
  
  def test_ROUND_regexp
    r = ROUND
    
    # plus syntax
    assert "--" =~ r
    assert_equal nil, $3
    assert_equal nil, $6
    
    assert "--+" =~ r
    assert_equal "+", $3
    assert_equal nil, $6
    
    assert "--++" =~ r
    assert_equal "++", $3
    assert_equal nil, $6
    
    assert "--+++" =~ r
    assert_equal "+++", $3
    assert_equal nil, $6
    
    assert "--++[]" =~ r
    assert_equal "++", $3
    assert_equal "", $6
    
    assert "--++[1,2,3]" =~ r
    assert_equal "++", $3
    assert_equal "1,2,3", $6
    
    # same without option break
    assert "+" =~ r
    assert_equal "+", $3
    assert_equal nil, $6
    
    assert "++" =~ r
    assert_equal "++", $3
    assert_equal nil, $6
    
    assert "+++" =~ r
    assert_equal "+++", $3
    assert_equal nil, $6
    
    assert "++[]" =~ r
    assert_equal "++", $3
    assert_equal "", $6

    assert "++[1,2,3]" =~ r
    assert_equal "++", $3
    assert_equal "1,2,3", $6
    
    # plus-number syntax
    assert "--+0" =~ r
    assert_equal "+0", $3
    assert_equal nil, $6
    
    assert "--+1" =~ r
    assert_equal "+1", $3
    assert_equal nil, $6
    
    assert "--+100" =~ r
    assert_equal "+100", $3
    assert_equal nil, $6
    
    assert "--+1[]" =~ r
    assert_equal "+1", $3
    assert_equal "", $6
    
    assert "--+1[1,2,3]" =~ r
    assert_equal "+1", $3
    assert_equal "1,2,3", $6
        
    # same without option break
    assert "+0" =~ r
    assert_equal "+0", $3
    assert_equal nil, $6
    
    assert "+1" =~ r
    assert_equal "+1", $3
    assert_equal nil, $6
    
    assert "+100" =~ r
    assert_equal "+100", $3
    assert_equal nil, $6
    
    assert "+1[]" =~ r
    assert_equal "+1", $3
    assert_equal "", $6
    
    assert "+1[1,2,3]" =~ r
    assert_equal "+1", $3
    assert_equal "1,2,3", $6
  end
  
  #
  # SEQUENCE test
  #
  
  def test_SEQUENCE_regexp
    r = SEQUENCE
    
    assert "--:" =~ r
    assert_equal ":", $2
    
    assert "--1:2" =~ r
    assert_equal "1:2", $2
    
    assert "--1:" =~ r
    assert_equal "1:", $2
    
    assert "--:2" =~ r
    assert_equal ":2", $2
    
    assert "--100:200" =~ r
    assert_equal "100:200", $2
    
    assert "--1:2:3" =~ r
    assert_equal "1:2:3", $2

    # same without option break
    assert ":" =~ r
    assert_equal ":", $2
    
    assert "1:2" =~ r
    assert_equal "1:2", $2
    
    assert "1:" =~ r
    assert_equal "1:", $2
    
    assert ":2" =~ r
    assert_equal ":2", $2
    
    assert "100:200" =~ r
    assert_equal "100:200", $2
    
    assert "1:2:3" =~ r
    assert_equal "1:2:3", $2
    
    # non-matching
    assert "--1" !~ r
    assert "-- 1 : 2" !~ r
    assert "1" !~ r
  end
  
  #
  # INSTANCE test
  #
  
  def test_INSTANCE_regexp
    r = INSTANCE
    
    assert "--*" =~ r
    assert_equal "", $2

    assert "--*1" =~ r
    assert_equal "1", $2
    
    assert "--*100" =~ r
    assert_equal "100", $2
    
    # same without option break
    assert "*" =~ r
    assert_equal "", $2

    assert "*1" =~ r
    assert_equal "1", $2
    
    assert "*100" =~ r
    assert_equal "100", $2
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
    assert_equal [1, []], parse_round("+", "")    
    assert_equal [2, [1,2,3]],  parse_round("+2", "1,2,3")
    assert_equal [0, []], parse_round(nil, nil)
  end
  
  def test_parse_rounds
    assert_equal [0, []], parse_round("", "")
    assert_equal [1, []], parse_round("+", "")
    assert_equal [2, []], parse_round("++", "")
    
    assert_equal [0, []], parse_round("+0", "")
    assert_equal [1, []], parse_round("+1", "")
    assert_equal [2, []], parse_round("+2", "")
    
    assert_equal [0, [1,2,3]],  parse_round("", "1,2,3")
    assert_equal [0, []], parse_round("", nil)
    assert_equal [0, []], parse_round(nil, "")
    assert_equal [0, []], parse_round(nil, nil)
  end
  
  #
  # parse_sequence test
  #
  
  def test_parse_sequence_documentation
    assert_equal [1, [2,3]], parse_sequence("1:2:3")
    assert_equal [:current_index, [1,2,:next_index]], parse_sequence(":1:2:")
  end
  
  def test_parse_sequence
    assert_equal [:current_index, [:next_index]], parse_sequence(":")
    assert_equal [1, [:next_index]], parse_sequence("1:")
    assert_equal [:current_index, [2]], parse_sequence(":2")
    assert_equal [1, [2]], parse_sequence("1:2")
    assert_equal [1, [2,3]], parse_sequence("1:2:3")
    assert_equal [100, [200,300]], parse_sequence("100:200:300")
    assert_equal [:current_index, [1,2,3,:next_index]], parse_sequence(":1:2:3:")
  end
  
  #
  # parse_instance test
  #
  
  def test_parse_instance_documentation
    assert_equal 1, parse_instance("1")
    assert_equal :next_index, parse_instance("")
  end
  
  #
  # parse_bracket test
  #
  
  def test_parse_bracket_documentation
    assert_equal [1, [2,3]], parse_bracket("1", "2,3")
    assert_equal [:current_index, [:next_index]], parse_bracket("", "")
    assert_equal [1, [:next_index]], parse_bracket("1", "")
    assert_equal [:current_index, [2,3]], parse_bracket("", "2,3")
  end
  
  def test_parse_bracket
    assert_equal [:current_index, [:next_index]], parse_bracket("", "")
    assert_equal [1, [:next_index]], parse_bracket("1", "")
    assert_equal [:current_index, [2]], parse_bracket("", "2")
    assert_equal [1, [2]], parse_bracket("1", "2")
    assert_equal [1, [2,3]], parse_bracket("1", "2,3")
    assert_equal [100, [200,300]], parse_bracket("100", "200,300")
  end
end

class ParserTest < Test::Unit::TestCase
  include Tap

  #
  # argvs tests
  #

  def test_argvs_split_args_along_all_invalid_and_workflow_lines
    %w{
      --
      --+
      --++
      --+1
      --:
      --1:2
      --1[2]
      --[]
    }.each do |split|
      parser = Parser.new ["a", "-b", "--c", split, "d", "-e", "--f", split, "x", "-y", "--z"]
      assert_equal [
        ["a", "-b", "--c"], 
        ["d", "-e", "--f"],
        ["x", "-y", "--z"]
      ], parser.argvs
    end
  end

  def test_argvs_includes_short_and_long_options
    parser = Parser.new ["a", "-b", "--c", "--", "d", "-e", "--f", "--", "x", "-y", "--z"]
    assert_equal [
      ["a", "-b", "--c"], 
      ["d", "-e", "--f"],
      ["x", "-y", "--z"]
    ], parser.argvs
  end
  
  def test_argvs_removes_empty_args
    parser = Parser.new ["a","--", "--", "b", "--", "--opt", "--", "c", "--", "--"]
    assert_equal [["a"], ["b"], ["--opt"], ["c"]], parser.argvs
  end
  
  #
  # rounds tests
  #
  
  def test_parser_assigns_tasks_to_rounds_using_plus_syntax
    parser = Parser.new ["--", "a", "--", "b", "--", "c"]
    assert_equal [[0,1,2]], parser.rounds
    
    parser = Parser.new ["--", "a", "--+", "b", "--++", "c"]
    assert_equal [[0],[1],[2]], parser.rounds
  end
  
  def test_parser_assigns_tasks_to_rounds_using_plus_number_syntax
    parser = Parser.new ["--+0", "a", "--+0", "b", "--+0", "c"]
    assert_equal [[0,1,2]], parser.rounds
    
    parser = Parser.new ["--+0", "a", "--+1", "b", "--+2", "c"]
    assert_equal [[0],[1],[2]], parser.rounds
  end
  
  def test_parser_assigns_tasks_to_rounds_with_target_syntax
    parser = Parser.new ["--+0[0,1,2]"]
    assert_equal [[0,1,2]], parser.rounds
    
    parser = Parser.new ["--+0[0,1]", "--+1[2]"]
    assert_equal [[0,1],[2]], parser.rounds
    
    parser = Parser.new ["+0[0]", "+2[1]", "--", "+1[2]"]
    assert_equal [[0],[2],[1]], parser.rounds
  end
  
  def test_rounds_may_be_reassigned
    parser = Parser.new ["--", "a", "--", "b", "--", "c"]
    assert_equal [[0,1,2]], parser.rounds
    
    parser.parse ["--+1[0,1,2]"]
    assert_equal [nil, [0,1,2]], parser.rounds
    
    parser = Parser.new ["--+", "a", "--+", "b", "--+", "c"]
    assert_equal [nil, [0,1,2]], parser.rounds
    
    parser.parse ["--+0[0,1,2]"]
    assert_equal [[0,1,2]], parser.rounds
    
    # reverse
    parser = Parser.new ["--+0[0,1,2]"]
    assert_equal [[0,1,2]], parser.rounds
    
    parser.parse ["--+", "a", "--+", "b", "--+", "c"]
    assert_equal [nil, [0,1,2]], parser.rounds
    
    parser = Parser.new ["--+1[0,1,2]"]
    assert_equal [nil, [0,1,2]], parser.rounds
    
    parser.parse ["--", "a", "--", "b", "--", "c"]
    assert_equal [[0,1,2]], parser.rounds
  end
  
  def test_parser_rounds_are_order_independent
    parser = Parser.new ["--+", "b", "--++", "c", "--", "a"]
    assert_equal [[2],[0],[1]], parser.rounds
  end
    
  def test_first_round_is_assumed_if_left_unstated
    parser = Parser.new ["a"]
    assert_equal [[0]], parser.rounds
    
    parser = Parser.new ["a", "--", "b"]
    assert_equal [[0, 1]], parser.rounds
  end
  
  def test_empty_rounds_are_allowed
    parser = Parser.new [ "--++", "a", "--+++", "b", "--+++++", "c"]
    assert_equal [nil, nil, [0],[1], nil, [2]], parser.rounds
  end
  
  #
  # sequence test
  #
  
  def test_sequences_are_parsed
    parser = Parser.new ["--1:2", "--3:4:5"]
    assert_equal [[1,[2]], [3,[4,5]]], parser.sequences
  end
  
  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new ["a", "--", "b", "--:100", "c", "--:200"]
    assert_equal [[1, [100]], [2, [200]]], parser.sequences
  end
  
  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new ["a", "--100:", "b", "--200:", "c"]
    assert_equal [[100, [1]], [200, [2]]], parser.sequences
  end
  
  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new ["a", "--:", "b", "--:", "c"]
    assert_equal [[0,[1]], [1,[2]]], parser.sequences
  end
  
  #
  # fork test
  #
  
  def test_forks_are_parsed
    parser = Parser.new ["--1[2]", "--3[4,5]"]
    assert_equal [[1,[2]], [3,[4,5]]], parser.forks
  end
  
  def test_fork_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new ["a", "--", "b", "--[100]", "c", "--[200,300]"]
    assert_equal [[1, [100]], [2, [200,300]]], parser.forks
  end
  
  #
  # merge test
  #
  
  def test_merges_are_parsed
    parser = Parser.new ["--1{2}", "--3{4,5}"]
    assert_equal [[1,[2]], [3,[4,5]]], parser.merges
  end
  
  def test_merge_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new ["a", "--", "b", "--{100}", "c", "--{200,300}"]
    assert_equal [[1, [100]], [2, [200,300]]], parser.merges
  end
  
  #
  # sync_merge test
  #
  
  def test_sync_merges_are_parsed
    parser = Parser.new ["--1(2)", "--3(4,5)"]
    assert_equal [[1,[2]], [3,[4,5]]], parser.sync_merges
  end
  
  def test_sync_merge_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new ["a", "--", "b", "--(100)", "c", "--(200,300)"]
    assert_equal [[1, [100]], [2, [200,300]]], parser.sync_merges
  end
end

