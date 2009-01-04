require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/audit'

class AuditTest < Test::Unit::TestCase
  include Tap::Support
  
  #
  # documentation test
  #
  
  def test_audit_documentation
    # initialize a new audit
    _a = Audit.new(:one, 1)
    assert_equal :one, _a.key
    assert_equal 1, _a.value
  
    # build a short trail
    _b = Audit.new(:two, 2, _a)
    _c = Audit.new(:three, 3, _b)
  
    assert_equal [], _a.sources
    assert_equal [_a], _b.sources
    assert_equal [_b], _c.sources
  
    assert_equal [_a,_b,_c], _c.trail
    assert_equal [:one, :two, :three], _c.trail {|audit| audit.key }
    assert_equal [1,2,3], _c.trail {|audit| audit.value }
  
    _d = Audit.new(:four, 4, _b)
    assert_equal [_a,_b,_d], _d.trail
  
    _e = Audit.new(:five, 5, _b)
    assert_equal [_a,_b,_e], _e.trail
  
    _f = Audit.new(:six, 6)
    _g = Audit.new(:seven, 7, _f)
    _h = Audit.new(:eight, 8, [_c,_d,_g])
    assert_equal [[[_a,_b,_c], [_a,_b,_d], [_f,_g]], _h], _h.trail
  
    expected = %q{
o-[one] 1
o-[two] 2
|
|-o-[three] 3
| |
`---o-[four] 4
  | |
  | | o-[six] 6
  | | o-[seven] 7
  | | |
  `-`-`-o-[eight] 8
}
    assert_equal expected, "\n" + _h.dump
  end
  
  #
  # Audit.dump test
  #
  
  def test_dump_with_sequence
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', [b])
    
    assert_equal %q{
o-[a] "one"
o-[b] "two"
o-[c] "three"
}, "\n" + Audit.dump(c,"") 
  end
    
  def test_dump_with_fork
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)

    assert_equal %q{
o-[a] "one"
|
|-o-[b] "two"
|  
`---o-[c] "three"
}, "\n" + Audit.dump([b,c],"")
  end

  def test_dump_with_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two')
    c = Audit.new(:c, 'three', [a,b])

    assert_equal %q{
o-[a] "one"
|
| o-[b] "two"
| |
`-`-o-[c] "three"
}, "\n" + Audit.dump(c,"")
  end
     
  def test_dump_with_fork_and_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)
    d = Audit.new(:d, 'four')
    e = Audit.new(:e, 'five', [b,c,d])
    
    assert_equal %q{
o-[a] "one"
|
|-o-[b] "two"
| |
`---o-[c] "three"
  | |
  | | o-[d] "four"
  | | |
  `-`-`-o-[e] "five"
}, "\n" + Audit.dump(e,"")
  end
  
  def test_dump_with_separate_tracks
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two')
    c = Audit.new(:c, 'three', [a,b])
    
    x = Audit.new(:x, 'one')
    y = Audit.new(:y, 'two')
    z = Audit.new(:z, 'three', [x,y])

    assert_equal %q{
o-[a] "one"
|
| o-[b] "two"
| |
`-`-o-[c] "three"
     
o-[x] "one"
|
| o-[y] "two"
| |
`-`-o-[z] "three"
}, "\n" + Audit.dump([c,z],"")
  end
  
  #
  # initialize test
  #
  
  def test_initialize_documentation
    _a = Audit.new(nil, nil, nil)
    assert_equal [], _a.sources
  
    _b = Audit.new(nil, nil, _a)
    assert_equal [_a], _b.sources
  
    _c = Audit.new(nil, nil, [_a,_b])
    assert_equal [_a,_b], _c.sources
  end
  
  def test_initialize
    a = Audit.new(:key, :value)
    assert_equal :key, a.key
    assert_equal :value, a.value
    assert_equal [], a.sources
  end
  
  #
  # splat tests
  #
  
  def test_splat_documentation
    _a = Audit.new(nil, [:x, :y, :z])
    _b,_c,_d = _a.splat
  
    assert_equal 0, _b.key
    assert_equal :x, _b.value
  
    assert_equal 1, _c.key
    assert_equal :y, _c.value
  
    assert_equal 2, _d.key
    assert_equal :z, _d.value
    assert_equal [_a,_d], _d.trail
  
    _a = Audit.new(nil, :value)
    assert_equal [_a], _a.splat
  end
  
  def test_splat_returns_array_of_Audits
    a = Audit.new(nil, [:zero, :one, :two])
    array = a.splat
    
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
  
  def test_splat_returns_array_of_self_if_not_array
    a = Audit.new(nil)
    assert_equal [a], a.splat
  end
  
  #
  # trail test
  #
  
  def test_trail_documentation
    _a = Audit.new(:one, 1)
    _b = Audit.new(:two, 2, _a)
    assert_equal [_a,_b], _b.trail
    
    _a = Audit.new(:one, 1)
    _b = Audit.new(:two, 2)
    _c = Audit.new(:three, 3, [_a, _b])
    assert_equal [[[_a],[_b]],_c], _c.trail
    
    assert_equal [[[1], [2]], 3], _c.trail {|audit| audit.value }
  end
  
  def test_trail_with_sequence
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [a, b, c], c.trail
  end
  
  def test_trail_collects_block_return
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [:a, :b, :c], c.trail {|audit| audit.key }
  end
  
  def test_trail_with_fork_and_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)
    d = Audit.new(:d, 'four')
    e = Audit.new(:e, 'five', [c,d])
    f = Audit.new(:f, 'six')
    g = Audit.new(:g, 'seven', [b,e,f])
    
    assert_equal [[[:a, :b], [[[:a, :c], [:d]], :e], [:f]], :g], g.trail {|audit| audit.key }
  end
  
end