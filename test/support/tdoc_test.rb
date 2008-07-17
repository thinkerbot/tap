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
  
end