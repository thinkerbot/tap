require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/auditor/array_audit'

class AuditTest < Test::Unit::TestCase
  ArrayAudit = Tap::Auditor::ArrayAudit
  
  #
  # to_ary tests
  #
  
  def test_to_ary_documentation
    _a = ArrayAudit.new(nil, [:x, :y, :z])
    _b,_c,_d = _a.to_ary
  
    assert_equal 0, _b.key
    assert_equal :x, _b.value
  
    assert_equal 1, _c.key
    assert_equal :y, _c.value
  
    assert_equal 2, _d.key
    assert_equal :z, _d.value
    assert_equal [_a,_d], _d.trail
  end
  
  def test_to_ary_returns_array_of_Audits
    a = ArrayAudit.new(nil, [:zero, :one, :two])
    array = a.to_ary
    
    assert_equal 3, array.length
    
    zero, one, two = array
    
    assert_equal 0, zero.key
    assert_equal :zero, zero.value
    assert_equal [a], zero.sources
    
    assert_equal 1, one.key
    assert_equal :one, one.value
    assert_equal [a], one.sources
    
    assert_equal 2, two.key
    assert_equal :two, two.value
    assert_equal [a], two.sources
  end
  
  class NonArrayValue
    def to_ary
      [1,2,3]
    end
  end
  
  def test_to_ary_casts_non_array_values_to_arrays
    a = ArrayAudit.new(nil, NonArrayValue.new)
    assert_equal [1,2,3], a.to_ary.collect {|audit| audit.value }
  end
  
  def splat(*args)
    args
  end
  
  def test_to_ary_allows_array_audits_to_be_used_in_splats
    _a = ArrayAudit.new(nil, [:x, :y, :z])
    assert_equal [:x, :y, :z], splat(*_a).collect {|audit| audit.value }
  end
  
  def test_array_audits_with_flatten
    _a = ArrayAudit.new(nil, [:a, :b, :c])
    _b = ArrayAudit.new(nil, [:x, :y, :z])
    
    assert_equal [:a, :b, :c, :x, :y, :z], [_a, _b].flatten.collect {|audit| audit.value }
  end
end