require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class OrderArrayTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :dh
  
  def setup
    @dh = OrderArray.new
  end

  def test_initialization
    assert_equal [], dh.to_a
  end
  
  def test_initialization_with_array
    dh = OrderArray.new [[:a, [1,2]]]
    assert_equal [[:a, [1,2]]], dh.to_a
  end
  
  def test_initialization_with_existing_order_array
    parent = OrderArray.new [[:a, [1,2]], [:b, [3,4]]]
    assert_equal parent.to_a, OrderArray.new(parent).to_a
  end
  
  def test_parent_is_decoupled_from_child
    parent = OrderArray.new [[:a, [1,2]], [:b, [3,4]]]
    child = OrderArray.new(parent)
    
    parent.add :c
    parent.add :a, 5

    child.add :C
    child.add :a, "five"
    
    assert_equal [[:a, [1,2,5]], [:b, [3,4]], [:c, []]], parent.to_a
    assert_equal [[:a, [1,2,"five"]], [:b, [3,4]], [:C, []]], child.to_a
  end
  
  def test_initialize_raises_argument_error_for_unacceptable_parent
    assert_raise(ArgumentError) { OrderArray.new "string" }
  end
  
  #
  # keys test
  #
  
  def test_keys_returns_all_keys
    dh = OrderArray.new [[:one, []], [:two, []]]
    assert_equal [:one, :two], dh.keys
  end
  
  #
  # values test
  #
  
  def test_values_returns_all_values
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal [1,2,3,4], dh.values
  end
  
  #
  # include? test
  #
  
  def test_include_is_true_if_the_value_is_declared_for_some_key
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert dh.include?(1)
    assert dh.include?(4)
    assert !dh.include?(5)
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_exists
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert dh.has_key?(:one)
    assert dh.has_key?(:two)
    assert !dh.has_key?(:non_existant)
  end
  
  #
  # key_for test 
  #
  
  def test_key_for_returns_the_key_for_the_specified_value
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal :one, dh.key_for(1)
    assert_equal :two, dh.key_for(4)
  end
  
  def test_key_for_returns_nil_if_the_value_is_not_included
    assert_nil dh.key_for(1)
  end
  
  #
  # values_for test 
  #
  
  def test_values_for_returns_the_values_for_the_specified_key
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal [1, 2], dh.values_for(:one)
    assert_equal [3, 4], dh.values_for(:two)
  end
  
  def test_values_for_returns_nil_if_the_ordered_array_does_not_have_the_key
    assert_nil dh.values_for(:non_existant)
  end
  
  #
  # add test
  #
  
  def test_add_adds_new_values_for_the_specified_key
    dh.add(:one, 1, 2)
    dh.add(:two, 3)
    dh.add(:one, 1, 4)
    dh.add(:three)
    assert_equal [[:one, [1, 2, 1, 4]], [:two, [3]], [:three, []]], dh.to_a
  end
  
  #
  # remove test
  #
  
  def test_remove_removes_the_specified_value
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    dh.remove(1)
    dh.remove(4)
    assert_equal [[:one, [2]], [:two, [3]]], dh.to_a
  end
  
  def test_remove_does_not_remove_a_key_even_if_no_values_are_specified
    dh = OrderArray.new [[:one, [1]]]
    dh.remove(1)
    assert_equal [[:one, []]], dh.to_a
  end
  
  def test_remove_does_not_raise_an_error_for_non_existant_values
    assert_nothing_raised { dh.remove(1) }
  end
  
  #
  # remove_key test
  #
  
  def test_remove_key_removes_all_values_for_the_specified_key
    dh = OrderArray.new [[:one, [1, 2]], [:two, [3, 4]]]
    dh.remove_key(:one)
    assert_equal [[:two, [3, 4]]], dh.to_a
  end
  
  def test_remove_key_does_not_raise_an_error_for_non_existant_keys
    assert_nothing_raised { dh.remove_key(:one) }
  end
  
  #
  # each test
  #
  
  def test_each_returns_each_key_value_pair_in_order
    dh = OrderArray.new [[:one, [1, 2]], [:two, []], [:three, 3]]
    results = []
    dh.each do |key, value|
      results << [key, value]
    end
    
    assert_equal [[:one, 1], [:one, 2], [:three, 3]], results
  end
  
end