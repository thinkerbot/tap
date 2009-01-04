# this checks to see that you can unset and reset 
# constants and retain the functionality of the
# constant.
require 'test/unit'

module TestMod
  CONST = 1
  
  module_function
  
  def function
    "in function"
  end
end

class Object
  old_ruby_token = remove_const(:TestMod)
  const_set(:NewName, old_ruby_token )
end

class ConstantsCheck < Test::Unit::TestCase

  def test_constant_redefinition
    assert_equal 1, NewName::CONST
    assert_equal "in function", NewName.function
  end
end