require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/lazy_attributes'

class LazyAttributesTest < Test::Unit::TestCase
  include Tap::Support
  
  # LazyAttributesTest::LazyClass::lazy subject
  # comment
  class LazyClass
    extend Tap::Support::LazyAttributes
    self.source_file = __FILE__
    
    lazy_attr :lazy
    lazy_attr :unknown
  end
  
  def test_lazy_attr_creates_accessor_for_lazydoc_attribute
    assert LazyClass.respond_to?(:lazy)
    
    assert_equal Lazydoc::Comment, LazyClass.lazy.class
    assert_equal "subject", LazyClass.lazy.subject
    assert_equal "comment", LazyClass.lazy.to_s
  end
  
  def test_lazy_attr_creates_new_comment_for_unknown_attributes
    assert LazyClass.respond_to?(:unknown)
    
    assert_equal Lazydoc::Comment, LazyClass.unknown.class
    assert_equal nil, LazyClass.unknown.subject
    
    comment = Lazydoc[__FILE__]['LazyAttributesTest::LazyClass']['unknown']
    assert_equal comment, LazyClass.unknown
  end
end