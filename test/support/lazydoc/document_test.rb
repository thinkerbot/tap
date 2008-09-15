require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/lazydoc/document'

class DocumentTest < Test::Unit::TestCase
  include Tap::Support::Lazydoc
  include Tap::Test::SubsetMethods
  
  attr_reader :doc

  def setup
    @doc = Document.new
  end
  
  #
  # initialize test
  #

  def test_initialize
    doc = Document.new
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