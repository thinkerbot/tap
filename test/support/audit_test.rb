require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/support/audit'

class AuditTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :audit, :a, :b
  
  def setup
    @audit = Audit.new('original')
    @a = setup_audit(:a, :b, :c)
    @b = setup_audit(:x, :y, :z)
  end
  
  #
  # methods to setup audits for testing, and tests of the setup
  #
  
  def setup_audit(*sources)
    audit = Audit.new
    sources.each do |source|
      value = case source
      when Array
        source.collect {|s| s.to_s }
      else
        source.to_s
      end
      
      audit._record(source, value)
    end
    audit
  end

  def test_setup
    assert_equal [nil], audit._sources
    assert_equal ['original'], audit._values
    assert_equal 'original', audit._original
    assert_equal 'original', audit._current
    
    assert_equal [:a, :b, :c], a._sources
    assert_equal ['a', 'b', 'c'], a._values
    assert_equal 'c', a._current
    assert_equal 'a', a._original
    
    assert_equal [:x, :y, :z], b._sources
    assert_equal ['x', 'y', 'z'], b._values  
    assert_equal 'z', b._current
    assert_equal 'x', b._original
    
    c = setup_audit([a, b, :c])
    assert_equal [[a, b, :c]], c._sources
    assert_equal [[a.to_s, b.to_s, 'c']], c._values
  end
  
  #
  # documentation tests
  #
  
  def test_documentation
    # initialize a new audit
    a = Audit.new(1, nil)
  
    # record some values
    a._record(:A, 2)
    a._record(:B, 3)

    assert_equal [nil, :A, :B], a._source_trail 
    assert_equal [1, 2, 3], a._value_trail
    assert_equal 1, a._original
    assert_equal nil, a._original_source
    assert_equal 3, a._current
    assert_equal :B, a._current_source

    b = Audit.new(10, nil)
    b._record(:C, 11)
    b._record(:D, 12)  
  
    c = Audit.merge(a, b)
    assert_equal [ [[nil, :A, :B], [nil, :C, :D]] ], c._source_trail
    assert_equal [ [[1,2,3], [10, 11, 12]] ], c._value_trail   
    assert_equal [3, 12], c._current
  
    c._record(:E, "a string value")
    c._record(:F, {'a' => 'hash value'})
    c._record(:G, ['an', 'array', 'value'])
  
    assert_equal [ [[nil, :A, :B], [nil, :C, :D]], :E, :F, :G], c._source_trail
    assert_equal [ [[1,2,3], [10, 11, 12]], "a string value", {'a' => 'hash value'}, ['an', 'array', 'value']], c._value_trail
  
    a1 = a._fork
    a._record(:X, -1)
    a1._record(:Y, -2)

    assert_equal [nil, :A, :B, :X], a._source_trail
    assert_equal [nil, :A, :B, :Y], a1._source_trail
    assert_equal [ [[nil, :A, :B], [nil, :C, :D]], :E, :F, :G], c._source_trail 

    expected = %Q{o-[] 1
o-[A] 2
o-[B] 3
| 
| o-[] 10
| o-[C] 11
| o-[D] 12
| | 
`-`-o-[E] "a string value"
    o-[F] {"a"=>"hash value"}
    o-[G] ["an", "array", "value"]
}

    assert_equal expected, c._to_s
  end

  #   
  # Audit merge tests
  #

  def test_merge_documentation
    a = Audit.new
    a._record(:a, 'a')

    b = Audit.new
    b._record(:b, 'b')

    c = Audit.merge(a, b, 1)
    c._record(:c, 'c')

    assert_equal [['a','b', 1], 'c'], c._values
    assert_equal [AuditMerge[a, b, Audit.new(1)], :c], c._sources
  end

  def test_merge
    c = Audit.merge(a, b, 'p')
    c._record(:q, 'q')
    c._record(:r, 'r')
  
    assert_equal [AuditMerge[a, b, Audit.new('p')], :q, :r], c._sources
    assert_equal [['c', 'z', 'p'], 'q', 'r'], c._values
  
    assert_equal [[[:a, :b, :c], [:x, :y, :z], [nil]], :q, :r], c._source_trail
    assert_equal [[['a', 'b', 'c'], ['x', 'y', 'z'], ['p']], 'q', 'r'], c._value_trail
  end

  def test_merge_with_one_input_returns_fork
    c = Audit.merge(a)
    assert_equal c, a
  end

  def test_merge_with_no_inputs_returns_new_audit
    a = Audit.merge
    assert_equal Audit.new, a
  end

  #
  # record tests
  #
  
  def test_record
    audit._record(:a, 'next')
    audit._record(:b, 'final')
    
    assert_equal [nil, :a, :b], audit._sources
    assert_equal ['original', 'next', 'final'], audit._values
  end
  
  def test_record_with_arrays_and_audits
    audit._record(:a, a)
    audit._record(:array, [a, b, 'str'])
    
    assert_equal [nil, :a, :array], audit._sources
    assert_equal ['original', a, [a, b, 'str']], audit._values
  end

  def test_record_returns_self
    assert audit, audit._record(:a, 'next')
  end

  #
  # original tests
  #
  
  def test_original_is_first_recorded_value
    a = Audit.new('a', :a)
    assert_equal 'a', a._original
    
    audit._record(:b, 'next')
    assert_equal 'a', a._original
  end
  
  def test_original_source_is_original_recorded_source
    a = Audit.new('a', :a)
    assert_equal :a, a._original_source
    
    audit._record(:b, 'next')
    assert_equal :a, a._original_source
  end  

  #
  # current tests
  #
  
  def test_current_is_last_recorded_value
    audit._record(:a, 'next')
    assert_equal 'next', audit._current
    
    audit._record(:a, 'final')
    assert_equal 'final', audit._current
  end
  
  def test_current_source_is_last_recorded_source
    audit._record(:a, 'next')
    assert_equal :a, audit._current_source
    
    audit._record(:b, 'final')
    assert_equal :b, audit._current_source
  end

  #
  # source trail tests
  #
  
  def test_source_trail_helper_method_is_hidden
    assert !a.respond_to?(:source_trail)
    assert_raise(NoMethodError) { a.source_trail }
  end
  
  def test_source_trail_returns_all_sources
    a = setup_audit(:a, :b, :c)

    assert_equal [:a, :b, :c], a._source_trail
  end
  
  def test_source_trail_returns_source_trail_when_source_is_an_audit
    c = setup_audit(:p, a, :q)
    
    assert_equal [:p, a, :q], c._sources
    assert_equal [:p, [:a, :b, :c], :q], c._source_trail
  end
  
  def test_source_trail_resolves_each_member_in_an_audit_merge_source
    c = setup_audit(:p, AuditMerge[a, b, :q], [:r, :s], :t)

    assert_equal [:p, [[:a, :b, :c], [:x, :y, :z], :q],[:r, :s], :t], c._source_trail
  end
  
  #
  # value trail tests
  #
  
  def test_value_trail_helper_method_is_hidden
    assert !a.respond_to?(:value_trail)
    assert_raise(NoMethodError) { a.value_trail }
  end
  
  def test_value_trail_returns_all_values
    a = setup_audit(:a, :b, :c)

    assert_equal ['a', 'b', 'c'], a._value_trail
  end
  
  def test_value_trail_returns_value_trail_when_source_is_an_audit
    c = setup_audit(:p, a, :q)
    
    assert_equal [:p, a, :q], c._sources
    assert_equal ['p', ['a', 'b', 'c'], 'q'], c._value_trail
  end
  
  def test_value_trail_resolves_each_member_in_an_audit_merge_source
    c = setup_audit(:p, AuditMerge[a, b, :q], [:r, :s], :t)

    assert_equal ['p', [['a', 'b', 'c'], ['x', 'y', 'z'], 'q'],['r', 's'], 't'], c._value_trail
  end
  
  #
  # test fork  
  #
  
  def test_fork_returns_audit_with_duplicates_of_sources_and_values
    a = setup_audit(:a, :b, :c)
    b = a._fork
    
    assert_equal b._sources, a._sources
    assert_not_equal b._sources.object_id, a._sources.object_id
    assert_equal b._values, a._values
    assert_not_equal b._values.object_id, a._values.object_id
  end
  
  def test_forks_can_be_developed_independently
    a = setup_audit(:a, :b)
    b = a._fork
    
    a._record(:c, 'c')
    b._record(:d, 'd')

    assert_equal([:a, :b, :c], a._sources)
    assert_equal([:a, :b, :d], b._sources)
  end
  
  #
  # split tests
  #
  
  def test_split_forks_and_records_result_yielding_to_current
    block = lambda { |current| current += 'ar' }
    c = a._split(&block)
    
    assert_equal [:a, :b, :c, AuditSplit.new(block)], c._sources
    assert_equal ['a', 'b', 'c', 'car'], c._values
  end
  
  def test_split_raises_error_if_no_block_given
    assert_raise(LocalJumpError) { a._split }
  end
  
  #
  # expand tests
  #
  
  def test_expand_forks_for_and_records_each_in_current
    a = Audit.new([1,2,3])
    e = a._expand
    
    assert_equal 3, e.length
    
    assert_equal [nil, AuditExpand.new(0)], e[0]._sources
    assert_equal [[1,2,3], 1],  e[0]._values
    
    assert_equal [nil, AuditExpand.new(1)], e[1]._sources
    assert_equal [[1,2,3], 2],  e[1]._values
    
    assert_equal [nil, AuditExpand.new(2)], e[2]._sources
    assert_equal [[1,2,3], 3],  e[2]._values
  end
  
  def test_expand_raises_error_if_current_does_not_respond_to_each
    a = Audit.new(nil)
    assert_raise(NoMethodError) { a._expand }
  end
  
  #
  # _to_s test
  #

  def new_audit(letter, n=0)
    a = Tap::Support::Audit.new
    1.upto(n) {|i| a._record(letter, "#{letter}#{i}")}
    a
  end

  def test_to_s_for_sequence
    a = Audit.new
    assert_equal %Q{\n}, a._to_s

    a = new_audit(:a, 3)
    assert_equal %Q{
o-[a] "a1"
o-[a] "a2"
o-[a] "a3"
}[1..-1], a._to_s
  end

  def test_to_s_for_fork_is_same_as_forked
    a = new_audit(:a)
    assert_equal a._to_s, a._fork._to_s

    a = new_audit(:a, 3)._fork
    assert_equal a._to_s, a._fork._to_s
  end

  def test_to_s_for_merge_without_additional_records
    a = new_audit(:a, 3)
    b = new_audit(:b, 3)
    c = Tap::Support::Audit.merge(a,b)

    assert_equal %Q{
o-[a] "a1"
o-[a] "a2"
o-[a] "a3"
| 
| o-[b] "b1"
| o-[b] "b2"
| o-[b] "b3"
}[1..-1], c._to_s
  end

  def test_to_s_for_merge_with_additional_records
    a = new_audit(:a, 3)
    b = new_audit(:b, 3)
    c = Tap::Support::Audit.merge(a,b)
    1.upto(3) {|i| c._record(:c, "c#{i}")}
   
    assert_equal %Q{
o-[a] "a1"
o-[a] "a2"
o-[a] "a3"
| 
| o-[b] "b1"
| o-[b] "b2"
| o-[b] "b3"
| | 
`-`-o-[c] "c1"
    o-[c] "c2"
    o-[c] "c3"
}[1..-1], c._to_s
  end
  
  def test_to_s_for_merge_with_multiple_input_audits
    a = new_audit(:a, 1)
    b = new_audit(:b, 1)
    c = Tap::Support::Audit.merge(a,b)
    1.upto(1) {|i| c._record(:c, "c#{i}")}
    
    d = new_audit(:d, 1)
    e = new_audit(:e, 1)
    f = Tap::Support::Audit.merge(d, e, 'x1', 'y1', 'z1')
    1.upto(1) {|i| f._record(:f, "f#{i}")}
    
    g = Tap::Support::Audit.merge(c, f)
    1.upto(1) {|i| g._record(:g, "g#{i}")}

    assert_equal %Q{
o-[a] "a1"
| 
| o-[b] "b1"
| | 
`-`-o-[c] "c1"
    | 
    | o-[d] "d1"
    | | 
    | | o-[e] "e1"
    | | | 
    | | | o-[] "x1"
    | | | | 
    | | | | o-[] "y1"
    | | | | | 
    | | | | | o-[] "z1"
    | | | | | | 
    | `-`-`-`-`-o-[f] "f1"
    |           | 
    `-----------`-o-[g] "g1"
}[1..-1], g._to_s
  end
  
  
end