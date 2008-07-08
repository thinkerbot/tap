require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/cdoc'

class CDocTest < Test::Unit::TestCase
  include Tap::Support
  
  #
  # CDOC_REGEXP test
  #
  
  def test_CDOC_REGEXP
    r = CDoc::CDOC_REGEXP
    
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
    CDoc.scan(%Q{
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
    CDoc.parse(%Q{
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
}) do |namespace, key, value, comment|
     results << [namespace, key, value, comment.lines]
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
    CDoc.parse(%Q{
# Name::Space::key value1
# :startdoc:Name::Space::key value2
# :startdoc: Name::Space::key value3
# ::key value4
# :startdoc::key value5
# :startdoc: ::key value6
blah blah # ::key value7
# Name::Space::novalue
# ::novalue
}) do |namespace, key, value, comment|
     results << [namespace, key, value]
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
    CDoc.parse(%Q{
# ::key
# comment1 spanning
# multiple lines
# ::key
# comment2 spanning
# multiple lines
# ::key-end
# ignored
}) do |namespace, key, value, comment|
     results << comment.lines
   end

   assert_equal 2, results.length
   assert_equal [['comment1 spanning', 'multiple lines']], results[0]
   assert_equal [['comment2 spanning', 'multiple lines']], results[1]
  end
  
  def test_parse_ignores
    results = []
    CDoc.parse(%Q{
# Skipped::Key
# skipped::Key
# :skipped:
# skipped
skipped
}) do |namespace, key, value, comment|
     results << [namespace, key, value]
   end

   assert results.empty?
  end

end