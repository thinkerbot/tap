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
    assert_equal [1,[2,3], {}], parse_sequence("1:2:3", '')
    assert_equal [:previous_index,[1,2,:current_index], {}], parse_sequence(":1:2:", '')
  end
  
  def test_parse_sequence
    assert_equal [:previous_index,[:current_index], {}], parse_sequence(":", '')
    assert_equal [1,[:current_index], {}], parse_sequence("1:", '')
    assert_equal [:previous_index,[2], {}], parse_sequence(":2", '')
    assert_equal [1,[2], {}], parse_sequence("1:2", '')
    assert_equal [1,[2,3], {}], parse_sequence("1:2:3", '')
    assert_equal [100,[200,300], {}], parse_sequence("100:200:300", '')
    assert_equal [:previous_index,[1,2,3,:current_index], {}], parse_sequence(":1:2:3:", '')
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
    parser = Parser.new ["--", "a", "--", "b", "--", "c"]
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  
    parser = Parser.new ["--", "a", "--+", "b", "--++", "c"]
    assert_equal [[0],[1],[2]], parser.schema.rounds(true)
  end
  
  def test_parser_assigns_tasks_to_rounds_using_plus_number_syntax
    parser = Parser.new ["--+0", "a", "--+0", "b", "--+0", "c"]
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  
    parser = Parser.new ["--+0", "a", "--+1", "b", "--+2", "c"]
    assert_equal [[0],[1],[2]], parser.schema.rounds(true)
  end
  
  def test_parser_assigns_tasks_to_rounds_with_target_syntax
    parser = Parser.new ["--+0[0,1,2]"]
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  
    parser = Parser.new ["--+0[0,1]", "--+1[2]"]
    assert_equal [[0,1],[2]], parser.schema.rounds(true)
  end
  
  def test_rounds_may_be_reassigned
    parser = Parser.new ["--", "a", "--", "b", "--", "c"]
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  
    parser = Parser.new ["--", "a", "--", "b", "--", "c", "--+1[0,1,2]"]
    assert_equal [nil, [0,1,2]], parser.schema.rounds(true)
  
    # reverse
    parser = Parser.new ["--+0[0,1,2]"]
    assert_equal [[0,1,2]], parser.schema.rounds(true)
  
    parser = Parser.new ["--+0[0,1,2]", "--+", "a", "--+", "b", "--+", "c"]
    assert_equal [nil, [0,1,2]], parser.schema.rounds(true)
  end
  
  def test_parser_rounds_are_order_independent
    parser = Parser.new ["--+", "b", "--++", "c", "--", "a"]
    assert_equal [[2],[0],[1]], parser.schema.rounds(true)
  end
  
  def test_first_round_is_assumed_if_left_unstated
    parser = Parser.new ["a"]
    assert_equal [[0]], parser.schema.rounds(true)
  
    parser = Parser.new ["a", "--", "b"]
    assert_equal [[0, 1]], parser.schema.rounds(true)
  end
  
  def test_empty_rounds_are_allowed
    parser = Parser.new [ "--++", "a", "--+++", "b", "--+++++", "c"]
    assert_equal [nil, nil, [0],[1], nil, [2]], parser.schema.rounds(true)
  end
  # 
  # #
  # # sequence test
  # #
  # 
  # def test_sequences_are_parsed
  #   parser = Parser.new ["--1:2", "--3:4:5is"]
  #   assert_equal [[1,[2],''],[3,[4],'is'], [4,[5],'is']], parser.workflow(:sequence)
  # end
  #  
  # def test_sequences_may_be_reassigned
  #   parser = Parser.new ["a", "--:", "b", "--:", "c"]
  #   assert_equal [[0,[1],''],[1,[2],'']], parser.workflow(:sequence)
  #  
  #   parser = Parser.new ["a", "--:", "b", "--:", "c", "--1:0:2"]
  #   assert_equal [[0,[2],''],[1,[0],'']], parser.workflow(:sequence)
  #  
  #   # now in reverse
  #   parser = Parser.new ["--1:0:2"]
  #   assert_equal [[0,[2],''],[1,[0],'']], parser.workflow(:sequence)
  #  
  #   parser = Parser.new ["--1:0:2", "a", "--:", "b", "--:", "c"]
  #   assert_equal [[0,[1],''],[1,[2],'']], parser.workflow(:sequence)
  # end
  #  
  # def test_sequence_uses_the_last_count_if_no_lead_index_is_specified
  #   parser = Parser.new ["a", "--", "b", "--:100", "c", "--:200"]
  #   assert_equal [[1,[100],''],[2,[200],'']], parser.workflow(:sequence)
  # end
  #  
  # def test_sequence_uses_the_next_count_if_no_end_index_is_specified
  #   parser = Parser.new ["a", "--100:", "b", "--200:", "c"]
  #   assert_equal [[100,[1],''],[200,[2],'']], parser.workflow(:sequence)
  # end
  #  
  # def test_sequence_use_with_no_lead_or_end_index
  #   parser = Parser.new ["a", "--:", "b", "--:", "c"]
  #   assert_equal [[0,[1],''],[1,[2],'']], parser.workflow(:sequence)
  # end
  #  
  # #
  # # bracketed workflow test
  # # (fork, merge, sync_merge)
  # 
  # def bracket_test
  #   yield(:fork, '[', ']')
  #   yield(:merge, '{', '}')
  #   yield(:sync_merge, '(', ')')
  # end
  # 
  # def test_bracketed_workflows_are_parsed
  #   bracket_test do |type, l, r|
  #     parser = Parser.new ["--1#{l}2#{r}", "--3#{l}4,5#{r}"]
  #     assert_equal [[1,[2],''], [3,[4,5],'']], parser.workflow(type), type
  #   end
  # end
  # 
  # def test_bracketed_workflows_may_be_reassigned
  #   bracket_test do |type, l, r|
  #     parser = Parser.new ["--1#{l}2#{r}", "--3#{l}4,5#{r}"]
  #     assert_equal [[1,[2],''], [3,[4,5],'']], parser.workflow(type), type
  #   
  #     parser.parse ["1#{l}4,5#{r}", "--3#{l}2#{r}"]
  #     assert_equal [[1,[4,5],''], [3,[2],'']], parser.workflow(type), type
  #   end
  # end
  # 
  # def test_bracketed_workflows_uses_the_last_count_if_no_lead_index_is_specified
  #   bracket_test do |type, l, r|
  #     parser = Parser.new ["a", "--", "b", "--#{l}100#{r}", "c", "--#{l}200,300#{r}"]
  #     assert_equal [[1, [100],''], [2, [200,300],'']], parser.workflow(type), type
  #   end
  # end
  # 
  # #
  # # parse tests
  # #
  # 
  # def test_parse_documentation
  #   p = Parser.new "a -- b --+ c -- d -- e --+3[4]"
  #   assert_equal [[0,1,3],[2], nil, [4]], p.rounds
  # 
  #   p = Parser.new "a --: b -- c --1:2i"
  #   assert_equal [["a"], ["b"], ["c"]], p.argvs
  #   assert_equal [[0,[1],''],[1,[2],'i']], p.workflow(:sequence)
  # 
  #   p = Parser.new "a -- b --* global_name --config for --global"
  #   assert_equal [2], p.globals
  # 
  #   p = Parser.new "a -- b -- c"
  #   assert_equal [["a"], ["b"], ["c"]], p.argvs
  # 
  #   p = Parser.new "a -. -- b .- -- c"
  #   assert_equal [["a", "--", "b"], ["c"]], p.argvs
  # 
  #   p = Parser.new "a -- b --- c"
  #   assert_equal [["a"], ["b"]], p.argvs
  # end
  # 
  # def test_parse
  #   p = Parser.new [
  #     "a", "a1", "a2", "--key", "value", "--another", "another value",
  #     "--", "b","b1",
  #     "--", "c",
  #     "--+2[0,1,2]",
  #     "--0:1:2"]
  #     
  #   assert_equal [
  #     ["a", "a1", "a2", "--key", "value", "--another", "another value"],
  #     ["b", "b1"],
  #     ["c"]
  #   ], p.argvs
  #   
  #   assert_equal [nil, nil, [0]], p.rounds
  #   assert_equal [
  #     [0, [1], ''],
  #     [1, [2], '']
  #   ], p.workflow(:sequence)
  # end
  # 
  # def test_parse_splits_string_argv_using_shellwords
  #   p = Parser.new "a a1 a2 --key value --another 'another value' -- b b1 -- c --+2[0,1,2] --0:1:2"
  #   assert_equal [
  #     ["a", "a1", "a2", "--key", "value", "--another", "another value"],
  #     ["b", "b1"],
  #     ["c"]
  #   ], p.argvs
  #   
  #   assert_equal [nil, nil, [0]], p.rounds
  #   assert_equal [
  #     [0, [1], ''],
  #     [1, [2], '']
  #   ], p.workflow(:sequence)
  # end
  # 
  # def test_parse_is_non_destructive
  #   argv = [
  #     "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
  #     "b","b1", "--",
  #     "c", "--",
  #     "+2[0,1,2]", "--",
  #     "0:1:2"]
  #   argv_ref = argv.dup
  #   
  #   p = Parser.new argv
  #   assert_equal argv_ref, argv
  # end
  # 
  # def test_parse_does_not_parse_escaped_args
  #   p = Parser.new "a -. -- --: --1[2,3] 4{5,6} x y .- z -- b -- c"
  #   assert_equal [
  #     ["a", "--", "--:", "--1[2,3]", "4{5,6}", "x", "y", "z"],
  #     ["b"],
  #     ["c"]
  #   ], p.argvs
  # end
  # 
  # def test_parse_stops_at_end_flag
  #   p = Parser.new "a -- b --- c"
  #   assert_equal [["a"], ["b"]], p.argvs
  # end
  # 
  # #
  # # parse! test
  # #
  # 
  # def test_parse_bang_is_destructive
  #   argv = [
  #     "a", "a1", "a2", "--key", "value", "--another", "another value", "--",
  #     "b","b1", "--",
  #     "c", "--",
  #     "+2[0,1,2]", "--",
  #     "0:1:2"]
  #   argv_ref = argv.dup
  # 
  #   Parser.new.parse!(argv)
  #   assert argv.empty?
  # end
  # 
  # def test_parse_bang_stops_at_end_flag
  #   p = Parser.new
  #   args = p.parse! "a -- b --- c"
  #   assert_equal [["a"], ["b"]], p.argvs
  #   assert_equal ["c"], args
  # end
  # 
end