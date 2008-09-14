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
    expected = [
    ['comments spanning multiple', 'lines are collected'],
    [''],
    ['  while indented lines'],
    ['  are preserved individually'],
    [''],
    []]
    assert_equal expected, c.content   
    assert_equal "this is the subject line", c.subject
    
    c = Comment.parse(comment_string) {|frag| frag.strip.empty? }
    expected = [
    ['comments spanning multiple', 'lines are collected']]
    assert_equal expected, c.content   
    assert_equal nil, c.subject
  end
  
  # comment test will yield the string with both LF and CRLF
  # line endings; to ensure there is no dependency on the 
  # end of line style
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
      assert_equal [['comment', 'spanning lines', 'with whitespace']], c.content
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
      assert_equal [['comment', 'spanning lines', 'with whitespace']], c.content
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
      assert_equal [['comment'],[' with indented'], ["\tlines"], ['new spanning', 'line']], c.content
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
      assert_equal [['comment'],[''],[''],[' with indented'],[''],["\tlines"],[''],['new spanning', 'line']], c.content
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
      assert_equal [['comment', 'spanning lines']], c.content
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
      assert_equal [['comment', 'spanning lines']], c.content
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
      assert_equal [['comment']], c.content
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
      assert_equal [['comment']], c.content
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

      assert_equal [['comment']], c.content
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_does_not_set_subject_if_the_next_line_is_a_comment
    comment_test(%Q{
# comment

# not a subject line
})  do |str|
      c = Comment.parse(str)
      assert_equal [['comment']], c.content
      assert_equal nil, c.subject
    end
  end
  
  def test_parse_just_parses_subject_if_no_comments_are_given
    comment_test(%Q{

subject line
# ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [], c.content
      assert_equal 'subject line', c.subject
    end
  end
  
  def test_subjects_may_contain_trailing_comments
    comment_test(%Q{
subject line # with a trailing comment
# ignored
})  do |str|
      c = Comment.parse(str)
      assert_equal [], c.content
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
    
    expected = [
       ['comments spanning multiple', 'lines are collected'],
       [''],
       ['  while indented lines'],
       ['  are preserved individually'],
       [''],
       []]
    assert_equal(expected, c.content)
  end
  
  #
  # wrap test
  #
  
  def test_wraps_documentation
    assert_equal ["some line", "that will", "wrap"], Comment.wrap("some line that will wrap", 10)
    assert_equal ["     line", "that will", "wrap"], Comment.wrap("     line that will wrap    ", 10)
    assert_equal [], Comment.wrap("                            ", 10)
  end
  
  def test_wrap_breaks_on_newlines
    assert_equal ["line that", "will wrap", "a line", "that wont"], Comment.wrap("line that will wrap\na line\nthat wont", 10)
  end
  
  def test_preserves_multiple_newlines
    assert_equal ["line that", "", "", "", "will wrap"], Comment.wrap("line that\n\n\n\nwill wrap", 10)
  end
  
  def test_wrap_resolves_tabs_using_tabsize
    assert_equal ["a    line", "that", "wraps"], Comment.wrap("a\tline that\twraps", 10, 4)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Comment.new
    assert_equal [], c.content
    assert_equal nil, c.subject
    assert_equal nil, c.line_number
  end
  
  #
  # push test
  #
  
  def test_push_documentation
    c = Comment.new
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    expected = [
      ["some line", "fragments"], 
      ["a", "whole", "new line"]]
    assert_equal(expected, c.content)
  end
  
  def test_push_adds_fragment_to_last_line
    c.push "a line"
    c.push "fragment"
    assert_equal [["a line", "fragment"]], c.content
  end

  def test_push_adds_array_if_given
    c.push "fragment"
    c.push ["some", "array"]
    assert_equal [['fragment'], ["some", "array"]], c.content
  end

  def test_push_replaces_last_array_if_last_is_empty
    c.push ["some", "array"]
    assert_equal [["some", "array"]], c.content
  end
  
  #
  # append test
  #
  
  def test_append_documentation
    lines = [
      "# comment spanning multiple",
      "# lines",
      "#",
      "#   indented line one",
      "#   indented line two",
      "#    ",
      "not a comment line"]
  
    c = Comment.new
    lines.each {|line| c.append(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    [''],
    []]
    assert_equal expected, c.content
  end
  
  #
  # unshift test
  #
  
  def test_unshift_documentation
    c = Comment.new
    c.unshift "some line"
    c.unshift "fragments"
    c.unshift ["a", "whole", "new line"]
    
    expected = [
      ["a", "whole", "new line"], 
      ["fragments", "some line"]]
    assert_equal(expected, c.content)
  end
  
  def test_unshift_unshifts_fragment_to_first_line
    c.unshift "a line"
    c.unshift "fragment"
    assert_equal [["fragment", "a line"]], c.content
  end

  def test_unshift_unshifts_array_if_given
    c.unshift "fragment"
    c.unshift ["some", "array"]
    assert_equal [["some", "array"], ['fragment']], c.content
  end

  def test_unshift_replaces_first_array_if_first_is_empty
    c.unshift ["some", "array"]
    assert_equal [["some", "array"]], c.content
  end
  
  #
  # prepend test
  #
  
  def test_prepend_documentation
    lines = [
      "# comment spanning multiple",
      "# lines",
      "#",
      "#   indented line one",
      "#   indented line two",
      "#    ",
      "not a comment line"]
  
    c = Comment.new
    lines.reverse_each {|line| c.prepend(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    ['']]
    assert_equal expected, c.content
  end
  
  #
  # trim test
  #
  
  def test_trim_removes_leading_and_trailing_empty_and_whitespace_lines
    c.push ['']
    c.push ["fragment"]
    c.push ['', "\t\r  \n", ' ']
    c.push []
    
    assert_equal [[''],['fragment'],['', "\t\r  \n", ' '],[]], c.content
    c.trim
    assert_equal [['fragment']], c.content
  end
  
  def test_trim_ensures_lines_is_not_empty
    c.push ['']
    c.push ['']
    assert_equal [[''],['']], c.content
    
    c.trim
    assert_equal [], c.content
  end
  
  def test_trim_returns_self
    assert_equal c, c.trim
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_there_are_no_non_empty_lines_in_self
    assert_equal [], c.content
    assert c.empty?
    
    c.content.push "frag"
    
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
  
  #
  # wrap test
  #
  
  def test_wrap_wraps_to_s_to_the_specified_number_of_columns
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    expected = %Q{
some line
fragments
a whole
new line
}.strip

    assert_equal expected, c.wrap(10)
  end
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_another_is_a_Comment_and_they_have_the_same_line_number_subject_and_content
    a = Comment.new
    b = Comment.new
    
    c = Comment.new
    c.line_number = 10
    
    d = Comment.new
    d.subject = "subject"
    
    e = Comment.new
    e.push "frag"
    
    assert a == b
    assert a != c
    assert a != d
    assert a != e
  end
end