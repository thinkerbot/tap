require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class FrameworkMethodsTest < Test::Unit::TestCase
  
  #
  # default_name test
  #
  
  class NameClass
    extend Tap::Support::FrameworkMethods
    class NestedClass
      extend Tap::Support::FrameworkMethods
    end
  end
  
  def test_default_name_is_underscored_class_name_by_default
    assert_equal "framework_methods_test/name_class", NameClass.default_name
    assert_equal "framework_methods_test/name_class/nested_class", NameClass::NestedClass.default_name
  end
  
end
