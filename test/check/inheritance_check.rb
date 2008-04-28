require 'active_support'
require 'test/unit'

class ClassConfigurationTest < Test::Unit::TestCase
  class A
    write_inheritable_attribute(:hash, {})  
    class_inheritable_reader(:hash)
  
    self.hash[:one] = 'one'
  end

  class B < A
    self.hash[:one] = 1
  end

  def test_inheritance
    assert_not_equal A.hash, B.hash
    
    assert_equal 'one', A.hash[:one]
    assert_equal 1, B.hash[:one]
  end
end