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

# Sample::key <this is the subject line>
# a constant attribute content string that
# can span multiple lines...
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
  include Tap::Test::SubsetMethods
  
  attr_reader :doc

  def setup
    @doc = Lazydoc.new
  end
  
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
    assert_equal "<this is the subject line>", comment.subject
         
    expected = [
    ["a constant attribute content string that", "can span multiple lines..."],
    [""],
    ["  code.is_allowed"],
    ["  much.as_in RDoc"],
    [""],
    ["and stops at the next non-comment", "line, the next constant attribute,", "or an end key"]]
    assert_equal expected, comment.content
    
    expected = %q{
..............................
a constant attribute content
string that can span multiple
lines...

  code.is_allowed
  much.as_in RDoc

and stops at the next
non-comment line, the next
constant attribute, or an end
key
..............................
}
    assert_equal expected, "\n#{'.' * 30}\n" + comment.wrap(30) + "\n#{'.' * 30}\n"

    lazydoc = Sample.lazydoc.reset
    comment = lazydoc.register(/method_one/)
    
    lazydoc.resolve
    assert_equal "  def method_one", comment.subject
    assert_equal [["comment content for a code comment", "may similarly span multiple lines"]], comment.content
  
    str = %Q{
# Const::Name::key subject for key
# comment for key
# parsed until a 
# non-comment line

# Const::Name::another subject for another
# comment for another
# parsed to an end key
# Const::Name::another-
#
# ignored comment
}
  
    lazydoc = Lazydoc.new
    lazydoc.resolve(str)
    
    expected = {'Const::Name' => {
     'key' =>     ['subject for key', 'comment for key parsed until a non-comment line'],
     'another' => ['subject for another', 'comment for another parsed to an end key']
    }}
    assert_equal expected, lazydoc.to_hash {|comment| [comment.subject, comment.to_s] } 
  
    str = %Q{
Const::Name::not_parsed

# :::-
# Const::Name::not_parsed
# :::+
# Const::Name::parsed subject
}
  
    lazydoc = Lazydoc.new
    lazydoc.resolve(str)
    assert_equal({'Const::Name' => {'parsed' => 'subject'}}, lazydoc.to_hash {|comment| comment.subject })
  
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
  
    lazydoc = Lazydoc.new
    lazydoc.register(3)
    lazydoc.register(9)
    lazydoc.resolve(str)
  
    expected = [
    ['def method', 'comment lines for the method'],
    ['def another_method', 'as in RDoc, the comment can be separated from the method']]
    assert_equal expected, lazydoc.comments.collect {|comment| [comment.subject, comment.to_s] } 
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

    lazydoc = Lazydoc.new
    lazydoc.resolve(str)

    expected = {'Const::Name' => {
     'one' => ['hidden in RDoc', '* This line is visible in RDoc.'],
     'two' => ['', 'You can hide attribute comments like this.']
    }}
    assert_equal(expected, lazydoc.to_hash {|comment| [comment.subject, comment.to_s] })
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
    doc = Lazydoc.new('/path/to/file')
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc['/path/to/file']
  end

  def test_get_initializes_new_document_if_necessary
    assert !Lazydoc.registry.find {|doc| doc.source_file == '/path/for/non_existant_doc'}
    doc = Lazydoc['/path/for/non_existant_doc']
    assert Lazydoc.registry.include?(doc)
  end

  #
  # initialize test
  #

  def test_initialize
    doc = Lazydoc.new
    assert_equal(nil, doc.source_file)
    assert_equal('', doc.default_const_name)
    assert_equal({}, doc.const_attrs)
    assert_equal([], doc.comments)
    assert !doc.resolved
  end

  #
  # source_file= test
  #

  def test_set_source_file_sets_source_file_to_the_expanded_input_path
    assert_nil doc.source_file
    doc.source_file = "path/to/file.txt"
    assert_equal File.expand_path("path/to/file.txt"), doc.source_file
  end

  def test_source_file_may_be_set_to_nil
    doc.source_file = "path/to/file.txt"
    assert_not_nil doc.source_file
    doc.source_file = nil
    assert_nil doc.source_file
  end
  
  #
  # default_const_name= test
  #

  def test_set_default_const_name_sets_the_default_const_name
    assert_equal('', doc.default_const_name)
    doc.default_const_name = 'Const::Name'
    assert_equal('Const::Name', doc.default_const_name)
  end

  def test_set_default_const_name_merges_any_existing_default_const_attrs_with_const_attrs_for_the_new_name
    doc['']['one'] = 'value one'
    doc['']['two'] = 'value two'
    doc['New']['two'] = 'New value two'
    doc['New']['three'] = 'New value three'
    
    assert_equal({
      '' => {'one' => 'value one', 'two' => 'value two'},
      'New' => {'two' => 'New value two', 'three' => 'New value three'},
    }, doc.const_attrs)
    
    doc.default_const_name = 'New'
    assert_equal({
      'New' => {'one' => 'value one',  'two' => 'value two', 'three' => 'New value three'},
    }, doc.const_attrs)
  end

  #
  # AGET test
  #

  def test_AGET_returns_attributes_associated_with_the_const_name
    doc.const_attrs['Const::Name'] = {:one => 1}
    assert_equal({:one => 1}, doc['Const::Name'])
  end

  def test_AGET_initializes_hash_in_const_attrs_if_const_attrs_does_not_have_const_name_as_a_key
    assert doc.const_attrs.empty?
    assert_equal({}, doc['Const::Name'])
    assert_equal({'Const::Name' => {}}, doc.const_attrs)
  end

  #
  # register test
  #

  def test_register_adds_line_number_to_comments
    c1 = doc.register(1)
    assert_equal 1, c1.line_number

    c2 = doc.register(2)
    assert_equal 2, c2.line_number

    c3 = doc.register(3)
    assert_equal 3, c3.line_number

    assert_equal([c1, c2, c3], doc.comments)
  end

  #
  # resolve test
  #

  def test_resolve_parses_comments_from_str_for_source_file
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
    doc.comments.concat [c1, c2]
    doc.resolve(str)

    assert_equal [['comment one', 'spanning multiple lines'], [''], ['  indented line'], ['']], c1.content
    assert_equal "subject line one", c1.subject
    assert_equal 6, c1.line_number

    assert_equal [['comment two']], c2.content
    assert_equal "subject line two", c2.subject
    assert_equal 10, c2.line_number
  end

  def test_resolve_reads_const_attrs_from_str
    doc.resolve %Q{
# Name::Space::key subject line
# attribute comment
}

    assert doc.const_attrs.has_key?('Name::Space')
    assert doc.const_attrs['Name::Space'].has_key?('key')
    assert_equal [['attribute comment']], doc.const_attrs['Name::Space']['key'].content
    assert_equal 'subject line', doc.const_attrs['Name::Space']['key'].subject
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

    assert_equal [['comment one']], c.content
    assert_equal "subject line one", c.subject
    assert_equal 2, c.line_number

    assert doc.const_attrs.has_key?('Name::Space')
    assert doc.const_attrs['Name::Space'].has_key?('key')
    assert_equal [['attribute comment']], doc.const_attrs['Name::Space']['key'].content
    assert_equal 'subject line', doc.const_attrs['Name::Space']['key'].subject
  end

  def test_resolve_sets_resolved_to_true
    assert !doc.resolved
    doc.resolve ""
    assert doc.resolved
  end

  def test_resolve_does_nothing_if_already_resolved
    c1 = Comment.new(1)
    c2 = Comment.new(1)
    doc.comments << c1
    assert doc.resolve("# comment one\nsubject line one")

    doc.comments << c2
    assert !doc.resolve("# comment two\nsubject line two")

    assert_equal [['comment one']], c1.content
    assert_equal "subject line one", c1.subject

    assert_equal [], c2.content
    assert_equal nil, c2.subject
  end
  
end