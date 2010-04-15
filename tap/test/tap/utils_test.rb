require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/utils'

class UtilsTest < Test::Unit::TestCase
  include Tap::Utils
  
  #
  # shellsplit test
  #
  
  def test_shellsplit_strips_whitespace
    assert_equal ['a', 'b', 'c'], shellsplit("  a \t b \r\n c \n  ")
  end
  
  def test_shellsplit_respects_quoted_whitespace
    assert_equal ["\t a \t", 'b', "\n c \n"], shellsplit(" '\t a \t' b \r '\n c \n'  ")
  end
  
  def test_shellsplit_ignores_trailing_comments
    assert_equal ['a', 'b', 'c'], shellsplit("a b c # d")
  end
  
  #
  # capture_sh test
  #
  
  def test_capture_sh
    assert_equal "hello\n", capture_sh('echo hello')
  end
  
  def test_capture_sh_with_block
    was_in_block = false
    result = capture_sh('echo hello') do |ok, status|
      assert ok
      was_in_block = true
    end
    assert_equal "hello\n", result
    assert was_in_block
  end
end