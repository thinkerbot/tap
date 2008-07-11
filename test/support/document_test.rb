require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/document'

class DocumentTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :doc

  def setup
    @doc = Document.new
  end

  #
  # ATTRIBUTE_REGEXP test
  #

  def test_ATTRIBUTE_REGEXP
    r = Document::ATTRIBUTE_REGEXP

    assert r =~ "::key"
    assert_equal("::", $1)
    assert_equal("key", $3)

    assert r =~ ":startdoc::key"
    assert_equal("::", $1)
    assert_equal("key", $3)

    assert r =~ "Name::Space::key"
    assert_equal("Name::Space::", $1)
    assert_equal("key", $3)

    assert r =~ ":startdoc:Name::Space::key"
    assert_equal("Name::Space::", $1)
    assert_equal("key", $3)

    assert r !~ ": :key"
    assert r !~ "Name::Space:key"
    assert r !~ "Name::Space::Key"
  end

  #
  # scan test
  #

  def test_scan_only_finds_the_specified_key
    results = []
    Document.scan(%Q{
# Name::Space::key1 value1
# Name::Space::key value2
# Name::Space::key value3
# ::key
# Name::Space::key1 value4
}, "key") do |namespace, key, value|
     results << [namespace, key, value]
   end

   assert_equal [
     ["Name::Space", "key", "value2"],
     ["Name::Space", "key", "value3"],
     ["", "key", ""]
    ], results
  end

  #
  # parse test
  #

  def test_parse
    results = []
    Document.parse(%Q{
ignored
# leader

# Name::Space::key value
# comment spanning
# multiple lines
#   with indented
#   lines
#
# and a new
# spanning line

ignored
# trailer
}) do |namespace, key, comment|
     results << [namespace, key, comment.subject, comment.lines]
   end

   assert_equal 1, results.length
   assert_equal ["Name::Space", "key", "value", 
     [['comment spanning', 'multiple lines'],
     ['  with indented'],
     ['  lines'],
     [''],
     ['and a new', 'spanning line']]
    ], results[0]
  end

  def test_parse_with_various_declaration_syntaxes
    results = []
    Document.parse(%Q{
# Name::Space::key value1
# :startdoc:Name::Space::key value2
# :startdoc: Name::Space::key value3
# ::key value4
# :startdoc::key value5
# :startdoc: ::key value6
blah blah # ::key value7
# Name::Space::novalue
# ::novalue
}) do |namespace, key, comment|
     results << [namespace, key, comment.subject]
   end

   assert_equal [
     ["Name::Space", "key", "value1"],
     ["Name::Space", "key", "value2"],
     ["Name::Space", "key", "value3"],
     ["", "key", "value4"],
     ["", "key", "value5"],
     ["", "key", "value6"],
     ["", "key", "value7"],
     ["Name::Space", "novalue", ""],
     ["", "novalue", ""]
   ], results
  end

  def test_parse_stops_reading_comment_at_new_declaration_or_end_declaration
    results = []
    Document.parse(%Q{
# ::key
# comment1 spanning
# multiple lines
# ::key
# comment2 spanning
# multiple lines
# ::key-end
# ignored
}) do |namespace, key, comment|
     results << comment.lines
   end

   assert_equal 2, results.length
   assert_equal [['comment1 spanning', 'multiple lines']], results[0]
   assert_equal [['comment2 spanning', 'multiple lines']], results[1]
  end

  def test_parse_ignores
    results = []
    Document.parse(%Q{
# Skipped::Key
# skipped::Key
# :skipped:
# skipped
skipped
}) do |namespace, key, comment|
     results << [namespace, key, comment]
   end

   assert results.empty?
  end
  
  #
  # initialize test
  #

  def test_initialize
    doc = Document.new
    assert_equal(nil, doc.source_file)
    assert_equal({}, doc.attributes)
    assert_equal([], doc.code_comments)
    assert !doc.resolved?
  end

  #
  # register test
  #

  def test_register_adds_line_number_to_code_comments
    c1 = doc.register(1)
    assert_equal 1, c1.line_number

    c2 = doc.register(2)
    assert_equal 2, c2.line_number

    c3 = doc.register(3)
    assert_equal 3, c3.line_number

    assert_equal([c1, c2, c3], doc.code_comments)
  end

  #
  # resolve test
  #

  def test_resolve_parses_code_comments_from_str_for_source_file
    str = %Q{
# comment one
# spanning multiple lines
#
#   indented line
#    
subject line one

# comment two

subject line two

# ignored
not a subject line
}

    c1 = Comment.new(6)
    c2 = Comment.new(10)
    doc.code_comments.concat [c1, c2]
    doc.resolve(str)

    assert_equal [['comment one', 'spanning multiple lines'], [''], ['  indented line'], ['']], c1.lines
    assert_equal "subject line one", c1.subject
    assert_equal 6, c1.line_number

    assert_equal [['comment two']], c2.lines
    assert_equal "subject line two", c2.subject
    assert_equal 10, c2.line_number
  end

  def test_resolve_reads_attributes_from_str
    doc.resolve %Q{
# Name::Space::key subject line
# attribute comment
}

    assert doc.attributes.has_key?('Name::Space')
    assert doc.attributes['Name::Space'].has_key?('key')
    assert_equal [['attribute comment']], doc.attributes['Name::Space']['key'].lines
    assert_equal 'subject line', doc.attributes['Name::Space']['key'].subject
  end
  
  def test_resolve_reads_str_from_source_file_if_str_is_unspecified
    tempfile = Tempfile.new('register_test')
    tempfile << %Q{
# comment one
subject line one

# Name::Space::key subject line
# attribute comment 
}
    tempfile.close
    
    doc.source_file = tempfile.path
    c = doc.register(2)
    doc.resolve

    assert_equal [['comment one']], c.lines
    assert_equal "subject line one", c.subject
    assert_equal 2, c.line_number
    
    assert doc.attributes.has_key?('Name::Space')
    assert doc.attributes['Name::Space'].has_key?('key')
    assert_equal [['attribute comment']], doc.attributes['Name::Space']['key'].lines
    assert_equal 'subject line', doc.attributes['Name::Space']['key'].subject
  end
  
  def test_resolve_sets_resolved_to_true
    assert !doc.resolved?
    doc.resolve ""
    assert doc.resolved?
  end
  
  def test_resolve_does_nothing_if_already_resolved
    c1 = Comment.new(1)
    c2 = Comment.new(1)
    doc.code_comments << c1
    assert doc.resolve("# comment one\nsubject line one")
    
    doc.code_comments << c2
    assert !doc.resolve("# comment two\nsubject line two")
    
    assert_equal [['comment one']], c1.lines
    assert_equal "subject line one", c1.subject

    assert_equal [], c2.lines
    assert_equal nil, c2.subject
  end
end