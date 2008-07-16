require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/tdoc'

class TDocTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :c
  
  def setup
    @c = TDoc.new  
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = TDoc.new
    assert_equal([], c.registry)
  end
  
  #
  # document_for test
  #
  
  def test_document_for_returns_document_in_registry_for_source_file
    doc = Document.new('/path/to/file')
    c.registry << doc
    assert_equal doc, c.document_for('/path/to/file')
  end
  
  def test_document_for_initializes_new_document_if_necessary
    assert c.registry.empty?
    doc = c.document_for('/path/to/file')
    assert_equal [doc], c.registry 
  end
  
  #
  # documents_for_const
  #
  
  def test_documents_for_const_returns_all_documents_with_attrs_for_specified_const
    doc1 = Document.new
    doc1['Const::Name'][:key] = 'value'
    doc2 = Document.new
    doc2['Const::Name'][:key] = 'value'
    doc3 = Document.new
    
    c.registry << doc1 << doc2
    assert doc1.has_const?('Const::Name')
    assert doc2.has_const?('Const::Name')
    assert_equal([doc1, doc2], c.documents_for_const('Const::Name'))
  end
end