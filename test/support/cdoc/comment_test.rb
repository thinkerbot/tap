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
this is the target line

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
    
    assert_equal "this is the target line", c.target_line
  end
  
  def test_parse
    c = Comment.parse(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})
    assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
    assert_equal nil, c.target_line
  end

  def test_parse_accepts_string_scanner
    c = Comment.parse(StringScanner.new(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
}))
    assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
    assert_equal nil, c.target_line
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
    assert_equal nil, c.target_line
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
    assert_equal nil, c.target_line
  end
  
  def test_parse_stops_at_non_comment_line
    c = Comment.parse(%Q{
# comment
# spanning lines

# ignored
})
    assert_equal [['comment', 'spanning lines']], c.lines
    assert_equal nil, c.target_line
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
    assert_equal nil, c.target_line
  end
  
  def test_parse_sets_target_line_if_next_line_is_not_a_comment
    c = Comment.parse(%Q{
# comment
target line
ignored
})
    assert_equal [['comment']], c.lines
    assert_equal "target line", c.target_line
  end
  
  def test_parse_sets_target_line_as_next_non_comment_line
    c = Comment.parse(%Q{
# comment

target line
ignored
})
    assert_equal [['comment']], c.lines
    assert_equal "target line", c.target_line
  end
  
  def test_parse_does_not_set_target_line_if_comment_breaks_from_block
    c = Comment.parse(%Q{
# comment
# end
# ignored
not the target line
}) do |comment|
  comment =~ /^end/
end

    assert_equal [['comment']], c.lines
    assert_equal nil, c.target_line
  end
  
  def test_parse_does_not_set_target_line_if_the_next_line_is_a_comment
    c = Comment.parse(%Q{
# comment

# not a target line
})

    assert_equal [['comment']], c.lines
    assert_equal nil, c.target_line
  end
  
  def test_parse_just_parses_target_if_no_comments_are_given
    c = Comment.parse(%Q{

target line
# ignored
})

    assert_equal [], c.lines
    assert_equal 'target line', c.target_line
  end
  
  def test_target_lines_may_contain_trailing_comments
    c = Comment.parse(%Q{
target line # with a trailing comment
# ignored
})

    assert_equal [], c.lines
    assert_equal 'target line # with a trailing comment', c.target_line
  end
  
  def test_parse_can_handle_an_empty_or_whitespace_string_without_error
    assert_nothing_raised { Comment.parse("") }
    assert_nothing_raised { Comment.parse("\n   \t \r\n \f ") }
  end
  
  #
  # scan test
  #
  
  def test_scan_documentation
    lines = [
      "# comments spanning multiple",
      "# lines are collected",
      "#",
      "#   while indented lines",
      "#   are preserved individually",
      "#    ",
      "not a comment line",
      "# skipped since the loop breaks",
      "# at the first non-comment line"]

    c = Comment.new
    lines.each do |line|
      break unless Comment.scan(line) do |fragment|
        c.push(fragment)
      end
    end
     
    actual = c.lines   
    expected = [
       ['comments spanning multiple', 'lines are collected'],
       [''],
       ['  while indented lines'],
       ['  are preserved individually'],
       [''],
       []]
    assert_equal(expected, actual)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Comment.new
    assert_equal [], c.lines
    assert_equal nil, c.target_line
    assert_equal nil, c.line_number
  end
  
  #
  # unshift test
  #
  
  def test_unshift_documentation
    c = Comment.new
    c.unshift "some line"
    c.unshift "fragments"
    c.unshift ["a", "whole", "new line"]
    assert_equal([["a", "whole", "new line"], ["fragments", "some line"]], c.lines)
  end
  
  def test_unshift_unshifts_fragment_to_first_line
    c.unshift "a line"
    c.unshift "fragment"
    assert_equal [["fragment", "a line"]], c.lines
  end

  def test_unshift_unshifts_array_if_given
    c.unshift "fragment"
    c.unshift ["some", "array"]
    assert_equal [["some", "array"], ['fragment']], c.lines
  end

  def test_unshift_replaces_first_array_if_first_is_empty
    c.unshift ["some", "array"]
    assert_equal [["some", "array"]], c.lines
  end
  
  #
  # push test
  #
  
  def test_push_documentation
    c = Comment.new
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    assert_equal([["some line", "fragments"], ["a", "whole", "new line"]], c.lines)
  end
  
  def test_push_adds_fragment_to_last_line
    c.push "a line"
    c.push "fragment"
    assert_equal [["a line", "fragment"]], c.lines
  end

  def test_push_adds_array_if_given
    c.push "fragment"
    c.push ["some", "array"]
    assert_equal [['fragment'], ["some", "array"]], c.lines
  end

  def test_push_replaces_last_array_if_last_is_empty
    c.push ["some", "array"]
    assert_equal [["some", "array"]], c.lines
  end
  
  #
  # trim test
  #
  
  def test_trim_removes_leading_and_trailing_empty_and_whitespace_lines
    c.push ['']
    c.push ["fragment"]
    c.push ['', "\t\r  \n", ' ']
    c.push []
    
    assert_equal [[''],['fragment'],['', "\t\r  \n", ' '],[]], c.lines
    c.trim
    assert_equal [['fragment']], c.lines
  end
  
  def test_trim_ensures_lines_is_not_empty
    c.push ['']
    c.push ['']
    assert_equal [[''],['']], c.lines
    
    c.trim
    assert_equal [], c.lines
  end
  
  def test_trim_returns_self
    assert_equal c, c.trim
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_there_are_no_non_empty_lines_in_self
    assert_equal [], c.lines
    assert c.empty?
    
    c.lines.push "line"
    
    assert !c.empty?
  end
  
  #
  # to_s test
  #
  
  def test_to_s_joins_lines_with_separators
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    assert_equal "some line.fragments:a.whole.new line", c.to_s('.', ':')
  end
  
  def test_to_s_wraps_lines_to_cols
    c.push "some line that will wrap"
    assert_equal "some line\nthat will\nwrap", c.to_s(' ', "\n", 10)
  end
  
  def test_to_s_resolves_tabs_to_tabsize
    c.push "some\tresolved tab"
    assert_equal "some   resolved tab", c.to_s(' ', "\n", nil, 3)
  end
end