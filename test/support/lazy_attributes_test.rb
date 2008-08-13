require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/lazy_attributes'

class LazyAttributesTest < Test::Unit::TestCase
  
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
    
    assert_equal Tap::Support::Comment, LazyClass.lazy.class
    assert_equal "subject", LazyClass.lazy.subject
    assert_equal "comment", LazyClass.lazy.to_s
  end
  
  def test_lazy_attr_creates_new_comment_for_unknown_attributes
    assert LazyClass.respond_to?(:unknown)
    
    assert_equal Tap::Support::Comment, LazyClass.unknown.class
    assert_equal nil, LazyClass.unknown.subject
    
    comment = Tap::Support::Lazydoc[__FILE__].attributes('LazyAttributesTest::LazyClass')['unknown']
    assert_equal comment, LazyClass.unknown
  end
  
  # ::lazy default subject
  class AnotherLazyClass
    extend Tap::Support::LazyAttributes
    self.source_file = __FILE__
    
    lazy_attr :lazy
  end
  
  def test_lazy_attr_will_return_default_if_specified
    assert_equal "default subject", AnotherLazyClass.lazy.subject
  end
end