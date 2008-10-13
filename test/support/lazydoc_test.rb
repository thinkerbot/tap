require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/lazydoc'

# used in testing CALLER_REGEXP below
module CallerRegexpTestModule
  module_function
  def call(method, regexp)
    send("caller_test_#{method}", regexp)
  end
  def caller_test_pass(regexp)
    caller[0] =~ regexp
    $~
  end
  def caller_test_fail(regexp)
    "unmatching" =~ regexp
    $~
  end
end

# used in documentation test below

# Sample::key <value>
# This is the comment content.  A content
# string can span multiple lines...
#
#   code.is_allowed
#   much.as_in RDoc
#
# and stops at the next non-comment
# line, the next constant attribute,
# or an end key
class Sample
  extend Tap::Support::LazyAttributes
  self.source_file = __FILE__
  
  lazy_attr :key

  # comment content for a code comment
  # may similarly span multiple lines
  def method_one
  end
end

class LazydocTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetTest
  
  #
  # syntax test
  #

  module SyntaxSample
    def self.m
      "true"
    end
  end

  def m
    "true"
  end

  def test_lazydoc_syntax
    assert_equal "true", eval("SyntaxSample::m")

    assert_raise(SyntaxError) { eval("::m") }
    assert_raise(SyntaxError) { eval("SyntaxSample ::m") }

    assert_raise(SyntaxError) { eval(":::-") }
    assert_raise(SyntaxError) { eval("SyntaxSample :::-") }

    assert_raise(SyntaxError) { eval(":::+") }
    assert_raise(SyntaxError) { eval("SyntaxSample :::+") }
  end
  
  #
  # documentation test
  #
  
  def test_documentation 
    comment = Sample::key
    assert_equal "<value>", comment.subject
         
    expected = [
    ["This is the comment content.  A content", "string can span multiple lines..."],
    [""],
    ["  code.is_allowed"],
    ["  much.as_in RDoc"],
    [""],
    ["and stops at the next non-comment", "line, the next constant attribute,", "or an end key"]]
    assert_equal expected, comment.content
    
    expected = %q{
..............................
This is the comment content.
A content string can span
multiple lines...

  code.is_allowed
  much.as_in RDoc

and stops at the next
non-comment line, the next
constant attribute, or an end
key
..............................
}
    assert_equal expected, "\n#{'.' * 30}\n" + comment.wrap(30) + "\n#{'.' * 30}\n"

    doc = Sample.lazydoc.reset
    comment = doc.register(/method_one/)
    
    doc.resolve
    assert_equal "  def method_one", comment.subject
    assert_equal [["comment content for a code comment", "may similarly span multiple lines"]], comment.content
  
    str = %Q{
# Const::Name::key value for key
# comment for key
# parsed until a 
# non-comment line

# Const::Name::another value for another
# comment for another
# parsed to an end key
# Const::Name::another-
#
# ignored comment
}
  
    doc = Lazydoc::Document.new
    doc.resolve(str)
    
    expected = {'Const::Name' => {
     'key' =>     ['value for key', 'comment for key parsed until a non-comment line'],
     'another' => ['value for another', 'comment for another parsed to an end key']
    }}
    assert_equal expected, doc.to_hash {|c| [c.value, c.to_s] } 
  
    str = %Q{
Const::Name::not_parsed

# :::-
# Const::Name::not_parsed
# :::+
# Const::Name::parsed value
}
  
    doc = Lazydoc::Document.new
    doc.resolve(str)
    assert_equal({'Const::Name' => {'parsed' => 'value'}}, doc.to_hash {|c| c.value })
  
    str = %Q{
# comment lines for
# the method
def method
end

# as in RDoc, the comment can be
# separated from the method

def another_method
end
}
  
    doc = Lazydoc::Document.new
    doc.register(3)
    doc.register(9)
    doc.resolve(str)
  
    expected = [
    ['def method', 'comment lines for the method'],
    ['def another_method', 'as in RDoc, the comment can be separated from the method']]
    assert_equal expected, doc.comments.collect {|c| [c.subject, c.to_s] } 
  end

  def test_startdoc_syntax
    str = %Q{
# :start doc::Const::Name::one hidden in RDoc
# * This line is visible in RDoc.
# :start doc::Const::Name::one-
# 
#-- 
# Const::Name::two
# You can hide attribute comments like this.
# Const::Name::two-
#++
#
# * This line is also visible in RDoc.
}

    doc = Lazydoc::Document.new
    doc.resolve(str)

    expected = {'Const::Name' => {
     'one' => ['hidden in RDoc', '* This line is visible in RDoc.'],
     'two' => ['', 'You can hide attribute comments like this.']
    }}
    assert_equal(expected, doc.to_hash {|comment| [comment.subject, comment.to_s] })
  end
  
  #
  # ATTRIBUTE_REGEXP test
  #

  def test_ATTRIBUTE_REGEXP
    r = Lazydoc::ATTRIBUTE_REGEXP

    assert r =~ "::key"
    assert_equal [nil, "key", ""], [$1, $3, $4]
    
    assert r =~ "::key-"
    assert_equal [nil, "key", "-"], [$1, $3, $4]
    
    assert r =~ "Name::Space::key trailer"
    assert_equal ["Name::Space", "key", ""], [$1, $3, $4]

    assert r =~ "Name::Space::key- trailer"
    assert_equal ["Name::Space", "key", "-"], [$1, $3, $4]
    
    assert r !~ ": :key"
    assert r !~ "::\nkey"
    assert r !~ "Name::Space:key"
    assert r !~ "Name::Space::Key"
  end

  #
  # CONSTANT_REGEXP test
  #

  def test_CONSTANT_REGEXP
    r = Lazydoc::CONSTANT_REGEXP
    
    assert r =~ "# NameSpace"
    assert_equal "NameSpace", $1 
    
    assert r =~ "# Name::Space"
    assert_equal "Name::Space", $1
    
    assert r =~ " text # text Name::Space"
    assert_equal "Name::Space", $1
    
    assert r =~ "# text"
    assert_equal nil, $1
    
    assert r !~ "Name::Space"
  end
  
  #
  # CALLER_REGEXP test
  #

  def test_CALLER_REGEXP
    r = Lazydoc::CALLER_REGEXP
    
    result = CallerRegexpTestModule.call(:pass, r)
    assert_equal MatchData, result.class
    assert_equal __FILE__, result[1]
    assert_equal 8, result[3].to_i
    
    assert_nil CallerRegexpTestModule.call(:fail, r)
  end
  
  #
  # scan test
  #

  def test_scan_documentation
    str = %Q{
# Const::Name::key value
# ::alt alt_value
# 
# Ignored::Attribute::not_matched value
# :::-
# Ignored::key value
# :::+
# Another::key another value

Ignored::key value
}

    results = []
    Lazydoc.scan(str, 'key|alt') do |const_name, key, value|
      results << [const_name, key, value]
    end

    expected = [
    ['Const::Name', 'key', 'value'], 
    ['', 'alt', 'alt_value'], 
    ['Another', 'key', 'another value']]

    assert_equal expected, results
  end

  def test_scan_only_finds_the_specified_key
    results = []
    Lazydoc.scan(%Q{
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
     ["",  "key",  ""]
    ], results
  end

  def test_scan_skips_areas_flagged_as_off
    results = []
    Lazydoc.scan(%Q{
# Name::Space::key value1
# Name::Space:::-
# Name::Space::key value2
# Name::Space:::+
# Name::Space::key value3
}, "key") do |namespace, key, value|
     results << [namespace, key, value]
   end

   assert_equal [
     ["Name::Space", "key", "value1"],
     ["Name::Space", "key", "value3"]
    ], results
  end

  def test_scan_speed
    benchmark_test(25) do |x|
      str = %Q{#              key value} * 100
      n = 1000
      x.report("#{n}x #{str.length} chars") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space::key  value} * 100
      x.report("same but matching") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{#           ::key  value} * 100
      x.report("just ::key syntax") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space:: key value} * 100
      x.report("unmatching") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end
    end
  end

  #
  # parse test
  #

  def test_parse_documentation
    str = %Q{
# Const::Name::key subject for key
# comment for key

# :::-
# Ignored::key value
# :::+

# Ignored text before attribute ::another subject for another
# comment for another
}

    results = []
    Lazydoc.parse(str) do |const_name, key, comment|
      results << [const_name, key, comment.subject, comment.to_s]
    end

    expected = [
    ['Const::Name', 'key', 'subject for key', 'comment for key'], 
    ['', 'another', 'subject for another', 'comment for another']]

    assert_equal expected, results
  end

  def test_parse
    results = []
    Lazydoc.parse(%Q{
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
     results << [namespace, key, comment.subject, comment.content]
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
    Lazydoc.parse(%Q{
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
    Lazydoc.parse(%Q{
# ::key
# comment1 spanning
# multiple lines
# ::key
# comment2 spanning
# multiple lines
# ::key-
# ignored
}) do |namespace, key, comment|
     results << comment.content
   end

   assert_equal 2, results.length
   assert_equal [['comment1 spanning', 'multiple lines']], results[0]
   assert_equal [['comment2 spanning', 'multiple lines']], results[1]
  end

  def test_parse_ignores
    results = []
    Lazydoc.parse(%Q{
# Skipped::Key
# skipped::Key
# :skipped:
# skipped
skipped
Skipped::key
}) do |namespace, key, comment|
     results << [namespace, key, comment]
   end

   assert results.empty?
  end

  def test_parse_speed
    benchmark_test(25) do |x|
      comment = %Q{
# comment spanning
# multiple lines
#   with indented
#   lines
#
# and a new
# spanning line

}

      str = %Q{              key value#{comment}} * 10
      n = 100
      x.report("#{n}x #{str.length} chars") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{Name::Space::key  value#{comment}} * 10
      x.report("same but matching") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{           ::key  value#{comment}} * 10
      x.report("just ::key syntax") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{Name::Space:: key value#{comment}} * 10
      x.report("unmatching") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end
    end
  end

  #
  # registry test
  #

  def test_registry
    assert Lazydoc.registry.kind_of?(Array)
  end

  #
  # [] test
  #

  def test_get_returns_document_in_registry_for_source_file
    doc = Lazydoc::Document.new('/path/to/file')
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc['/path/to/file']
  end

  def test_get_initializes_new_document_if_necessary
    assert !Lazydoc.registry.find {|doc| doc.source_file == '/path/for/non_existant_doc'}
    doc = Lazydoc['/path/for/non_existant_doc']
    assert Lazydoc.registry.include?(doc)
  end

end