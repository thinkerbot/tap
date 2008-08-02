require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class FrameworkClassTest < Test::Unit::TestCase
  
  #
  # default_name test
  #
  
  class NameClass
    extend Tap::Support::FrameworkClass
    class NestedClass
      extend Tap::Support::FrameworkClass
    end
  end
  
  def test_default_name_is_underscored_class_name_by_default
    assert_equal "framework_class_test/name_class", NameClass.default_name
    assert_equal "framework_class_test/name_class/nested_class", NameClass::NestedClass.default_name
  end
  
end
