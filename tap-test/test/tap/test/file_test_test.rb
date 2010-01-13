require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test/file_test'

class FileTestTest < Test::Unit::TestCase
  include Tap::Test::FileTest
  
  #
  # method_root test
  #
  
  def test_each_test_method_has_a_method_root_which_is_a_sub_root_of_class_root
    assert method_root.kind_of?(Tap::Root)
    assert_equal class_root.path(method_name), method_root.path
  end
  
  def test_and_the_sub_path_is_method_name
    assert method_root.kind_of?(Tap::Root)
    assert_equal class_root.path(method_name), method_root.path
  end
end
