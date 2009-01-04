require 'test/unit'

module Base
  module A
    module B
    end
    
    def self.included(base)
      base.extend B
    end
  end
  
  module C
  end
  
  module D
    def self.included(base)
      base.extend C
    end
  end
end

module IncludesA
  include Base::A
end

module IncludesD
  include Base::D
end

class IncludeCheck < Test::Unit::TestCase
  
  def test_include_A
    assert IncludesA.ancestors.include?(Base::A)
    assert IncludesA.kind_of?(Base::A::B)
    assert_equal Base::A::B, IncludesA::B
    assert_equal ['B'], IncludesA.constants
    assert !IncludesA.const_defined?(:B)
  end
  
  def test_include_D
    assert IncludesD.ancestors.include?(Base::D)
    assert IncludesD.kind_of?(Base::C)
    assert_equal [], IncludesD.constants
    assert !IncludesD.const_defined?(:C)
  end
end