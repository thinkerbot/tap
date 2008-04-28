require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/validation'

class ValidationTest < Test::Unit::TestCase
  include Tap::Support::Validation
  
  #
  # validate test
  #
  
  def test_validate
    assert_equal 1, validate(1, Integer)
    assert_raise(ValidationError) { validate(nil, Integer) }
    assert_equal 1, validate(1, [Integer, nil])
    assert_equal nil, validate(nil, [Integer, nil])
    
    assert_equal "str", validate("str", /str/)
    assert_raise(ValidationError) { validate("str", /non/) }
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
  
end