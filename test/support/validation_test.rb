require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/validation'

class ValidationTest < Test::Unit::TestCase
  include Tap::Support::Validation
  
  #
  # validate test
  #
  
  def test_validate
    assert_raise(ValidationError) { validate(nil, []) }
    
    assert_equal 1, validate(1, [Integer])
    assert_raise(ValidationError) { validate(nil, [Integer]) }
    
    assert_equal 1, validate(1, [Integer, nil])
    assert_equal 1, validate(1, [1, nil])
    assert_equal nil, validate(nil, [Integer, nil])
    
    assert_equal "str", validate("str", [/str/])
    assert_raise(ValidationError) { validate("str", [/non/]) }
  end
  
  def test_all_inputs_are_valid_if_validations_is_nil
    assert_equal "str", validate("str", nil)
    assert_equal 1, validate(1, nil)
    assert_equal nil, validate(nil, nil)
  end
  
  def test_validate_raises_error_for_non_array_or_nil_inputs
    assert_raise(ArgumentError) { validate("str", "str") }
    assert_raise(ArgumentError) { validate("str", 1) }
  end
  
  #
  # check test
  #
  
  def test_check_returns_validation_block
    m = check(Integer)
    assert_equal Proc, m.class
    assert_equal 1, m.call(1)
    assert_raise(ValidationError) { m.call(nil) }
  end
  
  def test_check_raises_error_if_no_validations_are_specified
    assert_raise(ArgumentError) { check }
  end
  
  #
  # yaml test
  #
  
  def test_yaml_doc
    b = yaml(Integer, nil)
    assert_equal Proc, b.class
    assert_equal 1, b.call(1)
    assert_equal 1, b.call("1")
    assert_equal nil, b.call(nil)
    assert_raise(ValidationError) { b.call("str") }
  end
  
  def test_yaml_block_loads_strings_as_yaml_and_checks_result
    m = yaml(Integer)
    assert_equal Proc, m.class
    assert_equal 1, m.call(1)
    assert_equal 1, m.call("1")
    assert_raise(ValidationError) { m.call(nil) }
    assert_raise(ValidationError) { m.call("str") }
  end
  
  def test_yaml_is_not_validated_when_validations_are_not_specified
    m = yaml
    assert_nothing_raised do
      assert_equal nil, m.call(nil)
      assert_equal "str", m.call("str")
    end
  end
  
end