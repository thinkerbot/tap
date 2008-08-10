# checks the behavior of define_method, establishing
# that the define_method block executes in instance
# context.

require 'test/unit'

class DefineMethodCheck < Test::Unit::TestCase
  class A
    class << self
      def define_class_defined_method
        define_method('class_defined_method') do
          self
        end
      end
    end
    
    define_class_defined_method
  end

  def test_define_method_block_has_instance_contenxt
    a = A.new
    
    assert a.respond_to?(:class_defined_method)
    assert_equal a, a.class_defined_method
  end
end