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
    
    assert "--[]" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "", $3
    
    assert "--1[]" =~ r
    assert_equal "1", $1
    assert_equal "", $2
    assert_equal "", $3
    
    assert "--[2]" =~ r
    assert_equal "", $1
    assert_equal "2", $2
    assert_equal "", $3
    
    assert "--1[2]" =~ r
    assert_equal "1", $1
    assert_equal "2", $2
    assert_equal "", $3
    
    assert "--1[2,3,4]" =~ r
    assert_equal "1", $1
    assert_equal "2,3,4", $2
    assert_equal "", $3
  
    assert "--100[200,300,400]" =~ r
    assert_equal "100", $1
    assert_equal "200,300,400", $2
    assert_equal "", $3
    
    assert "--[]i" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "i", $3
    
    assert "--[]is" =~ r
    assert_equal "", $1
    assert_equal "", $2
    assert_equal "is", $3
    
    assert "--1[2,3,4]is" =~ r
    assert_equal "1", $1
    assert_equal "2,3,4", $2
    assert_equal "is", $3
    
    # non-matching
    assert "--1" !~ r
    assert "--1[2, 3, 4]" !~ r
    assert "1" !~ r
    assert "[]" !~ r
    assert "1[2,3,4]" !~ r
    assert "--[]1" !~ r
    assert "--1[2,3,4]1" !~ r
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
    assert_equal nil, $2
    assert_equal nil, $5
    
    assert "--+" =~ r
    assert_equal "+", $2
    assert_equal nil, $5
    
    assert "--++" =~ r
    assert_equal "++", $2
    assert_equal nil, $5
    
    assert "--+++" =~ r
    assert_equal "+++", $2
    assert_equal nil, $5
    
    assert "--++[]" =~ r
    assert_equal "++", $2
    assert_equal "", $5
    
    assert "--++[1,2,3]" =~ r
    assert_equal "++", $2
    assert_equal "1,2,3", $5
    
    # plus-number syntax
    assert "--+0" =~ r
    assert_equal "+0", $2
    assert_equal nil, $5
    
    assert "--+1" =~ r
    assert_equal "+1", $2
    assert_equal nil, $5
    
    assert "--+100" =~ r
    assert_equal "+100", $2
    assert_equal nil, $5
    
    assert "--+1[]" =~ r
    assert_equal "+1", $2
    assert_equal "", $5
    
    assert "--+1[1,2,3]" =~ r
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
    
    assert "--:" =~ r
    assert_equal ":", $1
    assert_equal "", $3
    
    assert "--1:2" =~ r
    assert_equal "1:2", $1
    assert_equal "", $3
    
    assert "--1:" =~ r
    assert_equal "1:", $1
    assert_equal "", $3
    
    assert "--:2" =~ r
    assert_equal ":2", $1
    assert_equal "", $3
    
    assert "--100:200" =~ r
    assert_equal "100:200", $1
    assert_equal "", $3
    
    assert "--1:2:3" =~ r
    assert_equal "1:2:3", $1
    assert_equal "", $3
  
    assert "--:i" =~ r
    assert_equal ":", $1
    assert_equal "i", $3
    
    assert "--1:2is" =~ r
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
    
    assert "--*" =~ r
    assert_equal "", $1
  
    assert "--*1" =~ r
    assert_equal "1", $1
    
    assert "--*100" =~ r
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
    assert_equal [1,2,3], parse_sequence("1:2:3")
    assert_equal [:previous_index,1,2,:current_index], parse_sequence(":1:2:")
  end

  def test_parse_sequence
    assert_equal [:previous_index,:current_index], parse_sequence(":")
    assert_equal [1,:current_index], parse_sequence("1:")
    assert_equal [:previous_index,2], parse_sequence(":2")
    assert_equal [1,2], parse_sequence("1:2")
    assert_equal [1,2,3], parse_sequence("1:2:3")
    assert_equal [100,200,300], parse_sequence("100:200:300")
    assert_equal [:previous_index,1,2,3,:current_index], parse_sequence(":1:2:3:")
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
    assert_equal [1, [2,3]], parse_bracket("1", "2,3")
    assert_equal [:previous_index, [:current_index]], parse_bracket("", "")
    assert_equal [1, [:current_index]], parse_bracket("1", "")
    assert_equal [:previous_index, [2,3]], parse_bracket("", "2,3")
  end

  def test_parse_bracket
    assert_equal [:previous_index, [:current_index]], parse_bracket("", "")
    assert_equal [1, [:current_index]], parse_bracket("1", "")
    assert_equal [:previous_index, [2]], parse_bracket("", "2")
    assert_equal [1, [2]], parse_bracket("1", "2")
    assert_equal [1, [2,3]], parse_bracket("1", "2,3")
    assert_equal [100, [200,300]], parse_bracket("100", "200,300")
  end
end