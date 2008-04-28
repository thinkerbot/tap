require File.join(File.dirname(__FILE__), 'tap_test_helper.rb') 
require 'tap/constants'

# used in tests
module ConstantNest
  module NestedConst
  end
end

class ConstantsTest < Test::Unit::TestCase

  def test_string_includes_constants
    assert String.ancestors.include?(Tap::Constants)
  end
  
  #
  # try_constantize test
  #
  
  def test_try_constantize_constantizes_or_yields_to_block
    was_in_block = false
    assert Object.const_defined?("String")
    assert_equal String, "String".try_constantize { was_in_block = true; "res" }
    assert !was_in_block
    
    was_in_block = false
    assert !Object.const_defined?("NonAConstant")
    assert_equal "res", "NonAConstant".try_constantize { was_in_block = true; "res" }
    assert was_in_block
  end
  
  #
  # constants_split test
  #
  
  def test_constants_split_splits_string_from_the_first_existing_constant
    assert Object.const_defined?("ConstantNest")
    assert_equal [ConstantNest, []], "ConstantNest".constants_split
    
    assert ConstantNest.const_defined?("NestedConst")
    assert_equal [ConstantNest::NestedConst, []], "ConstantNest::NestedConst".constants_split
    
    assert !ConstantNest::NestedConst.const_defined?("NonExistant")
    assert_equal [ConstantNest::NestedConst, ["NonExistant"]], "ConstantNest::NestedConst::NonExistant".constants_split
    assert_equal [ConstantNest::NestedConst, ["NonExistant", "Const"]], "ConstantNest::NestedConst::NonExistant::Const".constants_split
    
    assert_equal [Object, []], "Object".constants_split
    assert_equal [ConstantNest, []], "Object::ConstantNest".constants_split
    assert_equal [ConstantNest::NestedConst, []], "Object::ConstantNest::NestedConst".constants_split
    assert_equal [ConstantNest::NestedConst, ["NonExistant"]], "Object::ConstantNest::NestedConst::NonExistant".constants_split
    assert_equal [ConstantNest::NestedConst, ["NonExistant", "Const"]], "Object::ConstantNest::NestedConst::NonExistant::Const".constants_split
  end
  
  def test_constants_split_camelizes_first
    assert_equal [ConstantNest, []], "object/constant_nest".constants_split
  end
end