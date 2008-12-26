require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/support/audit'

class AuditTest < Test::Unit::TestCase
  include Tap::Support
  
  #
  # documentation test
  #
  
  def test_audit_documentation
    # initialize a new audit
    a = Audit.new(:one, 1)
    assert_equal :one, a.key
    assert_equal 1, a.value
  
    # build a short trail
    b = Audit.new(:two, 2, a)
    c = Audit.new(:three, 3, b)
  
    assert_equal [], a.sources
    assert_equal [a], b.sources
    assert_equal [b], c.sources
  
    assert_equal [a,b,c], c._trail
    assert_equal [:one, :two, :three], c._trail {|audit| audit.key }
    assert_equal [1,2,3], c._trail {|audit| audit.value }
  
    d = Audit.new(:four, 4, b)
    assert_equal [a,b,d], d._trail
  
    e = Audit.new(:five, 5, b)
    assert_equal [a,b,e], e._trail
  
    f = Audit.new(:six, 6)
    g = Audit.new(:seven, 7, f)
    h = Audit.new(:eight, 8, [c,d,g])
    assert_equal [[[a,b,c], [a,b,d], [f,g]], h], h._trail
    
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
    assert_equal expected, "\n" + h._to_s
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
  
  def test_initialize
    a = Audit.new(:key, :value)
    assert_equal :key, a.key
    assert_equal :value, a.value
    assert_equal [], a.sources
  end
  
  #
  # _iterate tests
  #
  
  def test__iterate_documentation
    a = Audit.new(nil, [:x, :y, :z])
    b,c,d = a._iterate
  
    assert_equal 0, b.key
    assert_equal :x, b.value
  
    assert_equal 1, c.key
    assert_equal :y, c.value
  
    assert_equal 2, d.key
    assert_equal :z, d.value
    assert_equal [a,d], d._trail
    
    a = Audit.new(nil, :value)
    assert_equal [a], a._iterate
  end
  
  def test__iterate_returns_array_of_Audits
    a = Audit.new(nil, [:zero, :one, :two])
    array = a._iterate
    
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
  
  def test__iterate_returns_array_of_self_if_not_array
    a = Audit.new(nil)
    assert_equal [a], a._iterate
  end
  
  #
  # _trail test
  #
  
  def test__trail_documentation
    a = Audit.new(:one, 1)
    b = Audit.new(:two, 2, a)
    assert_equal [a, b], b._trail
  
    a = Audit.new(:one, 1)
    b = Audit.new(:two, 2)
    c = Audit.new(:three, 3, [a, b])
    assert_equal [[[a], [b]], c], c._trail
  
    assert_equal [[[1], [2]], 3], c._trail {|audit| audit.value }
  end
  
  def test__trail_with_sequence
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [a, b, c], c._trail
  end
  
  def test__trail_collects_block_return
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [:a, :b, :c], c._trail {|audit| audit.key }
  end
  
  def test__trail_with_fork_and_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)
    d = Audit.new(:d, 'four')
    e = Audit.new(:e, 'five', [c,d])
    f = Audit.new(:f, 'six')
    g = Audit.new(:g, 'seven', [b,e,f])
    
    assert_equal [[[:a, :b], [[[:a, :c], [:d]], :e], [:f]], :g], g._trail {|audit| audit.key }
  end
  
end