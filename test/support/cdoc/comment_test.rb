require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/cdoc/comment'

class CommentTest < Test::Unit::TestCase
  include Tap::Support::CDoc
  
  attr_reader :c
  
  def setup
    @c = Comment.new
  end
  
  #
  # parse test
  #
  
  def test_parse_documentation
    comment_string = %Q{
# comments spanning multiple
# lines are collected
#
#   while indented lines
#   are preserved individually
#    

# this line is not parsed as it
# is after a non-comment line
}
  
    c = Comment.parse(comment_string)
    assert_equal([
    ['comments spanning multiple', 'lines are collected'],
    [''],
    ['  while indented lines'],
    ['  are preserved individually'],
    [''],
    []], c.lines)
  end
  
  def test_parse
    c = Comment.parse(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})
    assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
  end

  def test_parse_accepts_string_scanner
    c = Comment.parse(StringScanner.new %Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})
    assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
  end
  
  def test_parse_treats_indented_lines_as_new_lines
    c = Comment.parse(%Q{
# comment
#  with indented
# \tlines \t
# new spanning
# line
})
    assert_equal [['comment'],[' with indented'], ["\tlines"], ['new spanning', 'line']], c.lines
  end
  
  def test_parse_preserves_newlines
    c = Comment.parse(%Q{
# comment
#
#   \t   
#  with indented
#
# \tlines \t
#   \t  
# new spanning
# line
})
    assert_equal [['comment'],[''],[''],[' with indented'],[''],["\tlines"],[''],['new spanning', 'line']], c.lines
  end
  
  def test_parse_stops_at_non_comment_line
    c = Comment.parse(%Q{
# comment
# spanning lines

# ignored
})
    assert_equal [['comment', 'spanning lines']], c.lines
  end

  def test_parse_stops_when_block_returns_true
    c = Comment.parse(%Q{
# comment
# spanning lines
# end
# ignored
}) do |comment|
  comment =~ /^end/
end
    assert_equal [['comment', 'spanning lines']], c.lines
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Comment.new
    assert_equal [[]], c.lines
  end
  
  #
  # << test
  #
  
  def test_push_documentation
    c = Comment.new
    c << "some line"
    c << "fragments"
    c << ["a", "whole", "new line"]
    assert_equal([["some line", "fragments"], ["a", "whole", "new line"]], c.lines)
  end
  
  def test_push_adds_fragment_to_last_line
    c << "a line"
    c << "fragment"
    assert_equal [["a line", "fragment"]], c.lines
  end

  def test_push_adds_array_if_given
    c << "fragment"
    c << ["some", "array"]
    assert_equal [['fragment'], ["some", "array"]], c.lines
  end

  def test_push_replaces_last_array_if_last_is_empty
    c << ["some", "array"]
    assert_equal [["some", "array"]], c.lines
  end
  
  #
  # trim test
  #
  
  def test_trim_removes_leading_and_trailing_empty_and_whitespace_lines
    c << ['']
    c << ["fragment"]
    c << ['', "\t\r  \n", ' ']
    c << []
    
    assert_equal [[''],['fragment'],['', "\t\r  \n", ' '],[]], c.lines
    c.trim
    assert_equal [['fragment']], c.lines
  end
  
  def test_trim_ensures_lines_is_not_empty
    c << ['']
    c << ['']
    assert_equal [[''],['']], c.lines
    
    c.trim
    assert_equal [[]], c.lines
  end
  
  def test_trim_returns_self
    assert_equal c, c.trim
  end
  
  #
  # to_s test
  #
  
  def test_to_s_joins_lines_with_separators
    c << "some line"
    c << "fragments"
    c << ["a", "whole", "new line"]
    
    assert_equal "some line.fragments:a.whole.new line", c.to_s('.', ':')
  end
  
  def test_to_s_wraps_lines_to_cols
    c << "some line that will wrap"
    assert_equal "some line\nthat will\nwrap", c.to_s(' ', "\n", 10)
  end
  
  def test_to_s_resolves_tabs_to_tabsize
    c << "some\tresolved tab"
    assert_equal "some   resolved tab", c.to_s(' ', "\n", nil, 3)
  end
end