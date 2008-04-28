require 'test/unit'

class ClassConfigurationTest < Test::Unit::TestCase
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

  def test_self_in_define_method
    a = A.new
    
    assert a.respond_to?(:class_defined_method)
    assert_equal a, a.class_defined_method
  end
end