require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/combinator'

class CombinatorTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  include Tap::Support
  
  def test_initialize
    ca = Combinator.new
    cb = Combinator.new
    cc = Combinator.new
    
    [
      [[ca, cb, cc],    [ca, cb, cc]],                             # combinators are set directly
      [[[1], [2],       [3]], [[1], [2], [3]]],                    # arrays are set directly
      [[1,2,3],         [[1], [2], [3]]],                          # other types are turned into single member arrays
      [[nil, nil, nil], [[], [], []]],                             # nil returns an empty array
      [[["a"], {:one => 1}, nil],  [["a"], [{:one => 1}], []]]     # all together now
    ].each do |(set, expected)|
      c = Combinator.new(*set)
      assert_equal expected[0], c.a
      assert_equal Combinator, c.b.class
      assert_equal expected[1], c.b.a
      assert_equal expected[2], c.b.b 
    end
  end
  
  def self.zero_one_combs
    [[0,0],[0,1],[1,0],[1,1]]
  end
  
  def test_sets
    assert_equal [], Combinator.new([]).sets
    assert_equal [[1]], Combinator.new([1]).sets
    assert_equal [[1], [2]], Combinator.new([1], [2]).sets
    assert_equal [[1], [1,1]], Combinator.new([1], [1,1]).sets
    assert_equal [[1], [1,1], [1,1,1]], Combinator.new([1], [1,1], [1,1,1]).sets
    assert_equal [[1], [1,1], [1,1,1]], Combinator.new([1], nil, [1,1], [], [1,1,1]).sets
  end
  
  def test_length
    assert_equal 0, Combinator.new([]).length
    
    assert_equal 1, Combinator.new([1]).length
    assert_equal 1, Combinator.new([1], [1]).length
    assert_equal 1, Combinator.new([1], [1], [1]).length
    assert_equal 1, Combinator.new([1], [], [1]).length
    
    assert_equal 2, Combinator.new([1,1]).length
    assert_equal 4, Combinator.new([1,1], [1,1]).length
    assert_equal 8, Combinator.new([1,1], [1,1], [1,1]).length
    assert_equal 4, Combinator.new([1,1], [], [1,1]).length
  end
  
  #
  def test_each
    comb = Combinator.new([0,1], [0,1])
    combinations = []
    comb.each { |*c| combinations << c }
    
    assert_equal CombinatorTest.zero_one_combs, combinations
  end
  
  def test_each_overlooks_nils_and_empty_arrays
    # try with multiple orders
    [
    [[0,1], [], [0,1], nil],
    [[0,1], [0,1], [], nil],
    [nil, [0,1], [], [0,1]]
    ].each do |set|
      comb = Combinator.new(*set)
      combinations = []
      comb.each { |*c| combinations << c }
    
      assert_equal CombinatorTest.zero_one_combs, combinations
    end
  end 
  
  def test_collect
    comb = Combinator.new([0,1], [0,1])
    expected = CombinatorTest.zero_one_combs.collect { |c| c << 2 }
    assert_equal expected, comb.collect { |*c| c << 2 }
  end

  def test_collect_returns_all_if_no_block_given
    comb = Combinator.new([0,1], [0,1])
    assert_equal CombinatorTest.zero_one_combs, comb.collect
  end
  
  #
  def test_combinator_3_by_3_by_3
    comb = Combinator.new([0,1,2], [0,1,2], [0,1,2])
    expected = [
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 2],
    [0, 1, 0],
    [0, 1, 1],
    [0, 1, 2],
    [0, 2, 0],
    [0, 2, 1],
    [0, 2, 2],
    [1, 0, 0],
    [1, 0, 1],
    [1, 0, 2],
    [1, 1, 0],
    [1, 1, 1],
    [1, 1, 2],
    [1, 2, 0],
    [1, 2, 1],
    [1, 2, 2],
    [2, 0, 0],
    [2, 0, 1],
    [2, 0, 2],
    [2, 1, 0],
    [2, 1, 1],
    [2, 1, 2],
    [2, 2, 0],
    [2, 2, 1],
    [2, 2, 2],
    ]
    
    assert_equal 3*3*3, comb.length
    assert_equal expected, comb.collect
  end
  
  def test_combinator_3_by_2_by_3
    comb = Combinator.new([0,1,2], [0,1], [0,1,2])
    expected = [
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 2],
    [0, 1, 0],
    [0, 1, 1],
    [0, 1, 2],
    [1, 0, 0],
    [1, 0, 1],
    [1, 0, 2],
    [1, 1, 0],
    [1, 1, 1],
    [1, 1, 2],
    [2, 0, 0],
    [2, 0, 1],
    [2, 0, 2],
    [2, 1, 0],
    [2, 1, 1],
    [2, 1, 2],
    ]
    
    assert_equal 3*2*3, comb.length
    assert_equal expected, comb.collect
  end
  
  def test_combinator_3_by_2_by_1
    comb = Combinator.new([0,1,2], [0,1], [0])
    expected = [
    [0, 0, 0],
    [0, 1, 0],
    [1, 0, 0],
    [1, 1, 0],
    [2, 0, 0],
    [2, 1, 0],
    ]
    
    assert_equal 3*2*1, comb.length
    assert_equal expected, comb.collect
  end
  
  # From these tests, it looks like (sensibly) the Combinator is more sensitive to the
  # number of sets than to the number of items in each set. ie for ten items:
  #   Combinator.new([1,2],[1,2],[1,2],[1,2],[1,2])
  # runs slower than
  #  Combinator.new([1,2,3,4,5], [1,2,3,4,5])
  #
  # Of course they generate different output too... like [1,1,1,1,1] vs [1,1]... so you
  # really do not have a choice in how you structure the combination.
  def test_combination_speed
    benchmark_test(15) do |x|
      [[3,10],[10,3],[10,4],[10,5]].each do |trial|
        items, fold = *trial
        set = []
        sets = []
        length = items ** fold
        
        1.upto(items) {|i| set << i}
        fold.times { sets << set }
    
        c = Combinator.new(*sets)
        assert_equal length, c.length
        
        x.report("#{items}x#{fold} - #{length}") { assert_equal length, c.collect.length }

      end
    end
  end
end