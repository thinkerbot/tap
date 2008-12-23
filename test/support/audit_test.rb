require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/support/audit'

class AuditTest < Test::Unit::TestCase
  include Tap::Support
  
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
  # _source_trails test
  #
  
  def test__source_trails_with_sequence
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [[a, b, c]], c._source_trails
  end
  
  def test__source_trails_collects_block_return
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [[:a, :b, :c]], c._source_trails {|audit| audit.key }
  end
  
  def test__source_trails_with_fork_and_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)
    d = Audit.new(:d, 'four')
    e = Audit.new(:e, 'five', [c,d])
    f = Audit.new(:f, 'six')
    g = Audit.new(:g, 'seven', [b,e,f])
    
    assert_equal [
      [:a, :b, :g], 
      [:a, :c, :e, :g], 
      [:d, :e, :g], 
      [:f, :g]
    ], g._source_trails {|audit| audit.key }
  end
  
  #
  # _sink_trail test
  #
  
  def test__sink_trail_with_sequence
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [a, b, c], c._sink_trail
  end
  
  def test__sink_trail_collects_block_return
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', b)
    
    assert_equal [:a, :b, :c], c._sink_trail {|audit| audit.key }
  end
  
  def test__sink_trail_with_fork_and_merge
    a = Audit.new(:a, 'one')
    b = Audit.new(:b, 'two', a)
    c = Audit.new(:c, 'three', a)
    d = Audit.new(:d, 'four')
    e = Audit.new(:e, 'five', [c,d])
    f = Audit.new(:f, 'six')
    g = Audit.new(:g, 'seven', [b,e,f])
    
    assert_equal [[[:a, :b], [[[:a, :c], [:d]], :e], [:f]], :g], g._sink_trail {|audit| audit.key }
  end
  
end