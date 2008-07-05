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
  
  #
  # string test
  #
  
  def test_string_documentation
    assert_equal Proc, string.class
    assert_equal 'str', string.call('str') 
    assert_equal "\n", string.call('\n') 
    assert_equal "\n", string.call("\n") 
    assert_raise(ValidationError) { string.call(:sym) }
  end

  #
  # symbol test
  #

  def test_symbol_documentation
    assert_equal Proc, symbol.class
    assert_equal :sym, symbol.call(:sym)
    assert_equal :sym, symbol.call(':sym')
    assert_raise(ValidationError) { symbol.call('str') }
  end

  #
  # boolean test
  #

  def test_boolean_documentation
    assert_equal Proc, boolean.class
    assert_equal true, boolean.call(true)
    assert_equal false, boolean.call(false)

    assert_equal true, boolean.call('true')
    assert_equal true, boolean.call('yes')
    assert_equal nil, boolean.call(nil) 
    assert_equal false,boolean.call('FALSE')

    assert_raise(ValidationError) { boolean.call(1) }
    assert_raise(ValidationError) { boolean.call("str") }
  end

  def test_boolean_block_converts_input_to_boolean_using_yaml_and_checks_result
    assert_equal Proc, boolean.class

    assert_equal true, boolean.call(true)
    assert_equal true, boolean.call('true')
    assert_equal true, boolean.call('TRUE')
    assert_equal true, boolean.call('yes')

    assert_equal nil, boolean.call(nil)
    assert_equal false, boolean.call(false)
    assert_equal false, boolean.call('false')
    assert_equal false, boolean.call('FALSE')
    assert_equal false, boolean.call('no')

    assert_raise(ValidationError) { boolean.call(10) }
    assert_raise(ValidationError) { boolean.call("str") }
  end

  #
  # array test
  #

  def test_array_documentation
    assert_equal Proc, array.class
    assert_equal [1,2,3], array.call([1,2,3])
    assert_equal [1,2,3], array.call('[1, 2, 3]')
    assert_raise(ValidationError) { array.call('str') }
  end

  #
  # hash test
  #

  def test_hash_documentation
    assert_equal Proc, hash.class
    assert_equal({'key' => 'value'}, hash.call({'key' => 'value'}))
    assert_equal({'key' => 'value'}, hash.call('key: value'))
    assert_raise(ValidationError) { hash.call('str') }
  end

  #
  # integer test
  #

  def test_integer_documentation  
    assert_equal Proc, integer.class
    assert_equal 1, integer.call(1)
    assert_equal 1, integer.call('1')
    assert_raise(ValidationError) { integer.call(1.1) }
    assert_raise(ValidationError) { integer.call('str') }
  end

  #
  # float test
  #

  def test_float_documentation
    assert_equal Proc, float.class
    assert_equal 1.1, float.call(1.1)
    assert_equal 1.1, float.call('1.1')
    assert_raise(ValidationError) { float.call(1) }
    assert_raise(ValidationError) { float.call('str') }
  end
  
  #
  # regexp test
  #
  
  def test_regexp_documentation
    assert_equal Proc, regexp.class
    assert_equal(/regexp/, regexp.call(/regexp/))
    assert_equal(/regexp/, regexp.call('regexp'))
    assert_equal(/(?i)regexp/, regexp.call('(?i)regexp'))
  end

end