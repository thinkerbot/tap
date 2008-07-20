require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/comment'

class CommentTest < Test::Unit::TestCase
  include Tap::Support
  
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
this is the subject line

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
    
    assert_equal "this is the subject line", c.subject
  end
  
  def comment_test(str)
    yield(str.gsub(/\r?\n/, "\n"))
    yield(str.gsub(/\r?\n/, "\r\n"))
  end
  
  def test_parse
    comment_test(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
      assert_equal nil, c.subject
    end
  end

  def test_parse_accepts_string_scanner
    comment_test(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})  do |str|      
      c = Comment.parse(StringScanner.new(str))
      assert_equal [['comment', 'spanning lines', 'with whitespace']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_treats_indented_lines_as_new_lines
    comment_test(%Q{
# comment
#  with indented
# \tlines \t
# new spanning
# line
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment'],[' with indented'], ["\tlines"], ['new spanning', 'line']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_preserves_newlines
   comment_test(%Q{
# comment
#
#   \t   
#  with indented
#
# \tlines \t
#   \t  
# new spanning
# line
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment'],[''],[''],[' with indented'],[''],["\tlines"],[''],['new spanning', 'line']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_stops_at_non_comment_line
    comment_test(%Q{
# comment
# spanning lines

# ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment', 'spanning lines']], c.lines
      assert_equal nil, c.subject
    end
  end

  def test_parse_stops_when_block_returns_true
    comment_test(%Q{
# comment
# spanning lines
# end
# ignored
})  do |str|
      c = Comment.parse(str) do |comment|
        comment =~ /^end/
      end
      assert_equal [['comment', 'spanning lines']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_sets_subject_if_next_line_is_not_a_comment
    comment_test(%Q{
# comment
subject line
ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment']], c.lines
      assert_equal "subject line", c.subject
    end
  end
  
  def test_parse_sets_subject_as_next_non_comment_line
    comment_test(%Q{
# comment

subject line
ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment']], c.lines
      assert_equal "subject line", c.subject
    end
  end
  
  def test_parse_does_not_set_subject_if_comment_breaks_from_block
    comment_test(%Q{
# comment
# end
# ignored
not the subject line
})  do |str|
      c = Comment.parse(str) do |comment|
        comment =~ /^end/
      end

      assert_equal [['comment']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_does_not_set_subject_if_the_next_line_is_a_comment
    comment_test(%Q{
# comment

# not a subject line
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment']], c.lines
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_just_parses_subject_if_no_comments_are_given
    comment_test(%Q{

subject line
# ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [], c.lines
      assert_equal 'subject line', c.subject
    end
  end
  
  def test_subjects_may_contain_trailing_comments
    comment_test(%Q{
subject line # with a trailing comment
# ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [], c.lines
      assert_equal 'subject line # with a trailing comment', c.subject
    end
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
  # wrap test
  #
  
  def test_wraps_str_to_cols
    assert_equal ["some line", "that will", "wrap"], Comment.wrap("some line that will wrap", 10)
  end
  
  def test_wrap_breaks_on_newlines
    assert_equal ["line that", "will wrap", "a line", "that wont"], Comment.wrap("line that will wrap\na line\nthat wont", 10)
  end
  
  def test_wrap_resolves_tabs_using_tabsize
    assert_equal ["a    line", "that", "wraps"], Comment.wrap("a\tline that\twraps", 10, 4)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Comment.new
    assert_equal [], c.lines
    assert_equal nil, c.subject
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
  
  def test_to_s_does_not_join_lines_when_line_sep_is_nil
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    assert_equal ["some line.fragments", "a.whole.new line"], c.to_s('.', nil)
  end
end