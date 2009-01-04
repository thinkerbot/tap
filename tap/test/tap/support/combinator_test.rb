require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/combinator'

class CombinatorTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_subset_test
  
  def test_documentation
    c = Combinator.new [1,2], [3,4]
    assert_equal [[1,3], [1,4], [2,3], [2,4]], c.to_a        
    
    c = Combinator.new [1,2], [3,4], [5,6]
    assert_equal [[1],[2]], c.a             
    assert_equal Combinator, c.b.class      
    assert_equal [[3],[4]], c.b.a    
    assert_equal [[5],[6]], c.b.b
    
    assert_equal [1,3,5], ([1] + [3]) + [5]
  end
  
  #
  # initialize tests
  #
  
  def test_initialize
    c = Combinator.new
    assert_equal [], c.a
    assert_equal [], c.b
    
    {
      [[1], [2,3], [3, [4]]] =>[[[1]], [[2], [3]], [[3],[[4]]]],  # arrays have each element arrayified 
      [nil, nil, nil] => [[], [], []],                            # nil returns an empty array
      [[], [{:one => 1},nil], nil] => [[], [[{:one => 1}],[nil]], []]     # mixture
    }.each_pair do |sets, expected|
      c = Combinator.new(*sets)
      assert_equal expected[0], c.a
      assert_equal Combinator, c.b.class
      assert_equal expected[1], c.b.a
      assert_equal expected[2], c.b.b 
    end
  end
  
  def test_initialize_raises_error_unless_sets_are_all_arrays_combinators_or_nil
    [
      [1], 
      [[], 1], 
      [1,[]]
    ].each do |sets|
      assert_raise(ArgumentError) { Combinator.new(*sets) }
    end
  end

  #
  # sets test
  #
   
  def test_sets_returns_input_sets_minus_nil_or_empty_arrays
    [
      [],
      [[1]],
      [[1], [2]],
      [[1], [2,3], [4,5,6]],
      [[1], [2,[3]], [4,5,6]],
      [[1], nil, [], [4,5,6], nil]
    ].each do |sets|
      expected = sets.reject {|s| s.nil? || s.empty? }
      assert_equal expected, Combinator.new(*sets).sets, sets.inspect
    end
  end
  
  #
  # length test
  #
  
  def test_length
    {
      [] => 0,
      [[1]] => 1,
      [[1], [2]] => 1,
      [[1],[2],[3]] => 1,
      [[1],[], nil,[3]] => 1,
      
      [[1,2]] => 2,
      [[1], [2,3]] => 2,
      [[1,2], [3,4]] => 4,
      [[1,2], [3,4], [5,6]] => 8,
      [[1,2], nil, [3,4], [], [5,6]] => 8
    }.each_pair do |sets, expected|
      assert_equal expected, Combinator.new(*sets).length, sets.inspect
    end
  end
  
  #
  # each tests
  #
  
  def test_each
    {
      [[1]] => [[1]],
      [[1], [2]] => [[1,2]],
      [[1],[2],[3]] => [[1,2,3]],
      [[1],[], nil,[3]] => [[1,3]],
    
      [[1,2]] => [[1],[2]],
      [[1], [2,3]] => [[1,2], [1,3]],
      [[1,2], [3,4]] => [[1,3],[1,4],[2,3],[2,4]],
      [[1,2], [3,4], [5,6]] => [[1,3,5],[1,3,6],[1,4,5],[1,4,6],[2,3,5],[2,3,6],[2,4,5],[2,4,6]],
      [[1,2], nil, [3,4], [], [5,6]] => [[1,3,5],[1,3,6],[1,4,5],[1,4,6],[2,3,5],[2,3,6],[2,4,5],[2,4,6]]
    }.each_pair do |set, expected|
      comb = Combinator.new(*set)
      
      combinations = []
      comb.each { |c| combinations << c }
      assert_equal expected, combinations, set.inspect
    end
  end
  
  def test_each_with_deferencing
    comb = Combinator.new([1], [2,3])
    combinations = []
    comb.each { |a,b| combinations << [a,b] }
    
    assert_equal [[1,2], [1,3]], combinations
  end

  #
  # collect test
  #

  def test_collect
    comb = Combinator.new([0,1], [0,1])
    expected = [[0,0],[0,1],[1,0],[1,1]].collect { |c| c << 2 }
    assert_equal expected, comb.collect { |c| c << 2 }
  end
  
  #
  # to_a test
  #
  
  def test_to_a_returns_all_if_no_block_given
    comb = Combinator.new([0,1], [0,1])
    assert_equal [[0,0],[0,1],[1,0],[1,1]], comb.to_a
  end
  
  #
  # additional tests
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
    assert_equal expected, comb.to_a
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
    assert_equal expected, comb.to_a
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
    assert_equal expected, comb.to_a
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
          
        x.report("#{items}x#{fold} - #{length}") { assert_equal length, c.to_a.length }
      end
    end
  end

end