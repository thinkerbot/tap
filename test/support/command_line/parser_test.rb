require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/command_line/parser'

class Tap::Support::CommandLine::ParserTest < Test::Unit::TestCase
  include Tap::Support::CommandLine

  #
  # parse_yaml tests
  #
  
  def test_parse_yaml_documentation
    str = {'key' => 'value'}.to_yaml
    assert_equal "--- \nkey: value\n", str
    assert_equal({'key' => 'value'}, Parser.parse_yaml(str))
    assert_equal "str", Parser.parse_yaml("str")
  end
  
  def test_parse_yaml_loads_arg_if_arg_matches_yaml_document_string
    string = "---\nkey: value"
    assert_equal({"key" => "value"}, Parser.parse_yaml(string))
  end
  
  def test_parse_yaml_returns_arg_unless_matches_yaml_document_string
    string = "key: value"
    assert_equal("key: value", Parser.parse_yaml(string))
  end

  #
  # ROUND test
  #
  
  def test_ROUND_regexp
    r = Parser::ROUND
    
    # plus syntax
    assert "--" =~ r
    assert_equal "", $1
    assert_equal nil, $2
    
    assert "--+" =~ r
    assert_equal "+", $1
    assert_equal nil, $2
    
    assert "--++" =~ r
    assert_equal "++", $1
    assert_equal nil, $2
    
    assert "--+++" =~ r
    assert_equal "+++", $1
    assert_equal nil, $2
    
    # plus-number syntax
    assert "--+0" =~ r
    assert_equal "+0", $1
    assert_equal "0", $2
    
    assert "--+1" =~ r
    assert_equal "+1", $1
    assert_equal "1", $2
    
    assert "--+100" =~ r
    assert_equal "+100", $1
    assert_equal "100", $2
    
    # non-matching
    assert "goodnight" !~ r
    assert "moon" !~ r
    assert "8" !~ r
    
    assert "+" !~ r
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
  # SEQUENCE test
  #
  
  def test_SEQUENCE_regexp
    r = Parser::SEQUENCE
    
    assert "--:1" =~ r
    assert_equal ":1", $1
    
    assert "--:1" =~ r
    assert_equal ":1", $1
    
    assert "--1:" =~ r
    assert_equal "1:", $1
    
    assert "--1:2" =~ r
    assert_equal "1:2", $1
    
    assert "--100:200" =~ r
    assert_equal "100:200", $1
    
    assert "--:1:2:3" =~ r
    assert_equal ":1:2:3", $1
    
    assert "--1:2:3:" =~ r
    assert_equal "1:2:3:", $1
    
    assert "--:" =~ r
    assert_equal ":", $1
    
    # non-matching
    assert "--1" !~ r
    assert "-- 1 : 2" !~ r
  end

  #
  # bracket_regexp test
  #
  
  def test_bracket_regexp
    r = Parser.bracket_regexp("[", "]")
   
    assert "--1[2]" =~ r
    assert_equal "1", $1
    assert_equal "2", $2
    
    assert "--[2]" =~ r
    assert_equal "", $1
    assert_equal "2", $2
  
    assert "--1[2,3,4]" =~ r
    assert_equal "1", $1
    assert_equal "2,3,4", $2
  
    assert "--100[200,300,400]" =~ r
    assert_equal "100", $1
    assert_equal "200,300,400", $2
  
    assert "--1[]" =~ r
    assert_equal "1", $1
    assert_equal "", $2
    
    assert "--[]" =~ r
    assert_equal "", $1
    assert_equal "", $2
  
    assert "--1[,2,3,4]" =~ r
    assert_equal "1", $1
    assert_equal ",2,3,4", $2
  
    # non-matching
    assert "--1" !~ r
    assert "--1[2, 3, 4]" !~ r
  end

  #
  # INVALID test
  #
  
  def test_INVALID_regexp
    r = Parser::INVALID
    
    assert "--:" =~ r
    assert "--1[" =~ r
    assert "--1]" =~ r
    assert "--[]" =~ r
    assert "--()" =~ r
    assert "--{}" =~ r
    assert "--*" =~ r
  end
  
  #
  # argvs tests
  #
  
  def test_argvs_split_args_along_all_invalid_lines
    [ "--", "--+", "--++", "--+1", 
      "--:", "--1:2",
      "--1[2]", "--[]"
    ].each do |split|
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
    parser = Parser.new ["a","--", "--", "b", "--", "--opt", "--", "c"]
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
  
  def test_empty_rounds_are_removed
    parser = Parser.new [ "--++", "a", "--+++", "b", "--+++++", "c"]
    assert_equal [[0],[1],[2]], parser.rounds
  end
  
  # def test_rounds_do_not_include_
  #   parser = Parser.new [ "--++", "a", "--+++", "b", "--+++++", "c"]
  #   assert_equal [[0],[1],[2]], parser.rounds
  # end
  
  #
  # sequence test
  #

  def test_sequences_are_parsed
    parser = Parser.new ["--1:2", "--3:4:5"]
    assert_equal [[1,2], [3,4,5]], parser.sequences
  end

  def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
    parser = Parser.new ["a", "--", "b", "--:100", "c", "--:200"]
    assert_equal [[1, 100], [2, 200]], parser.sequences
  end

  def test_sequence_uses_the_next_count_if_no_end_index_is_specified
    parser = Parser.new ["a", "--100:", "b", "--200:", "c"]
    assert_equal [[100, 1], [200, 2]], parser.sequences
  end

  def test_sequence_use_with_no_lead_or_end_index
    parser = Parser.new ["a", "--:", "b", "--:", "c"]
    assert_equal [[0,1], [1,2]], parser.sequences
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