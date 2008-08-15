# this checks to see how class variables are inherited
require 'test/unit'

class Base
  @@var = 1
end

class Sub < Base
end

class ClassVariableCheck < Test::Unit::TestCase

  def test_class_variable_inheritance
    assert_equal 1, Base.send(:class_variable_get, :@@var)
    assert_equal 1, Sub.send(:class_variable_get, :@@var)
    
    Base.send(:class_variable_set, :@@var, 2)
    
    assert_equal 2, Base.send(:class_variable_get, :@@var)
    assert_equal 2, Sub.send(:class_variable_get, :@@var)
  end
end