require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class AssignmentsTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :a
  
  def setup
    @a = Assignments.new
  end
  
  def test_documentation
    a = Assignments.new
    a.assign(:one, 'one')
    a.assign(:two, 'two')
    a.assign(:one, 'ONE')
    assert_equal [[:one, ['one', 'ONE']], [:two, ['two']]], a.to_a
  
    b = Assignments.new(a)
    assert_equal [[:one, ['one', 'ONE']], [:two, ['two']]], b.to_a
  
    b.unassign('one')
    b.assign(:one, 1)
    assert_equal [[:one, ['ONE', 1]], [:two, ['two']]], b.to_a
    assert_equal [[:one, ['one', 'ONE']], [:two, ['two']]], a.to_a
  end

  #
  # initialization test 
  #

  def test_initialization
    assert_equal [], a.to_a
  end
  
  def test_initialization_with_array
    a = Assignments.new [[:a, [1,2]]]
    assert_equal [[:a, [1,2]]], a.to_a
  end
  
  def test_initialization_with_parent
    parent = Assignments.new [[:a, [1,2]], [:b, [3,4]]]
    assert_equal parent.to_a, Assignments.new(parent).to_a
  end
  
  def test_parent_is_decoupled_from_child
    parent = Assignments.new [[:a, [1,2]], [:b, [3,4]]]
    child = Assignments.new(parent)
    
    parent.assign :c
    parent.assign :a, 5

    child.assign :C
    child.assign :a, "five"
    
    assert_equal [[:a, [1,2,5]], [:b, [3,4]], [:c, []]], parent.to_a
    assert_equal [[:a, [1,2,"five"]], [:b, [3,4]], [:C, []]], child.to_a
  end
  
  def test_initialize_raises_argument_error_for_unacceptable_parent_object
    assert_raise(ArgumentError) { Assignments.new "string" }
  end
  
  def test_initialization_raises_argument_error_for_arrays_with_the_same_value_for_multiple_keys
    assert_raise(ArgumentError) { Assignments.new [[:a, [1]], [:b, [1]]] }
  end
  
  #
  # declare test
  #
  
  def test_declare_adds_key_with_empty_assignment_array_if_key_is_undeclared
    assert_equal [], a.to_a
    
    a.declare :one
    assert_equal [[:one, []]], a.to_a
    
    a.declare :one
    assert_equal [[:one, []]], a.to_a
  end
  
  #
  # undeclare test
  #
  
  def test_undeclare_removes_the_key_and_all_assigned_values
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    a.undeclare(:one)
    assert_equal [[:two, [3, 4]]], a.to_a
  end
  
  def test_undeclare_does_not_raise_an_error_for_non_existant_keys
    assert_nothing_raised { a.undeclare(:one) }
  end
  
  #
  # declared? test
  #
  
  def test_declared_is_true_if_the_key_is_declared
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert a.declared?(:one)
    assert a.declared?(:two)
    assert !a.declared?(:non_existant)
  end
  
  #
  # declarations test
  #
  
  def test_declarations_returns_all_keys
    a = Assignments.new [[:one, []], [:two, []]]
    assert_equal [:one, :two], a.declarations
  end
  
  #
  # assign test
  #
  
  def test_assign_assigns_new_values_to_the_specified_key
    a.assign(:one, 1, 2)
    a.assign(:two, 3)
    a.assign(:one, 1, 4)
    a.assign(:three)
    assert_equal [[:one, [1, 2, 4]], [:two, [3]], [:three, []]], a.to_a
  end
  
  def test_assign_raises_error_when_a_value_is_assigned_to_a_conflicting_key
    a.assign(:one, 1)
    assert_raise(ArgumentError) { a.assign(:two, 1) }
  end
  
  def test_assign_raises_error_for_nil_key
    assert_raise(ArgumentError) { a.assign(nil, 1) }
  end
  
  #
  # unassign test
  #
  
  def test_unassign_unassigns_the_specified_value
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    a.unassign(2)
    a.unassign(4)
    assert_equal [[:one, [1]], [:two, [3]]], a.to_a
  end
  
  def test_unassign_does_not_undeclare_key
    a = Assignments.new [[:one, [1]]]
    a.unassign(1)
    assert_equal [[:one, []]], a.to_a
  end
  
  def test_unassign_does_not_raise_an_error_for_non_existant_values
    assert_nothing_raised { a.unassign(1) }
  end
  
  #
  # assigned? test
  #
  
  def test_assigned_is_true_if_the_value_is_assigned_to_some_key
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert a.assigned?(1)
    assert a.assigned?(4)
    assert !a.assigned?(5)
  end
  
  #
  # values test
  #
  
  def test_values_returns_all_assigned_values
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal [1,2,3,4], a.values
  end

  #
  # key_for test 
  #
  
  def test_key_for_returns_the_keys_for_the_specified_value
    a = Assignments.new [[:one, [1]], [:two, [2]]]
    assert_equal :one, a.key_for(1)
    assert_equal :two, a.key_for(2)
  end
  
  def test_key_for_returns_nil_for_unassigned_values
    assert_nil a.key_for(4)
  end
  
  #
  # values_for test 
  #
  
  def test_values_for_returns_the_values_for_the_specified_key
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal [1, 2], a.values_for(:one)
    assert_equal [3, 4], a.values_for(:two)
  end
  
  def test_values_for_returns_nil_if_the_ordered_array_does_not_have_the_key
    assert_nil a.values_for(:non_existant)
  end

  #
  # each test
  #
  
  def test_each_returns_each_key_value_pair_in_order
    a = Assignments.new [[:one, [1, 2]], [:two, []], [:three, 3]]
    results = []
    a.each do |key, value|
      results << [key, value]
    end
    
    assert_equal [[:one, 1], [:one, 2], [:three, 3]], results
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_returns_each_key_values_pair_in_order
    a = Assignments.new [[:one, [1, 2]], [:two, []], [:three, 3]]
    results = []
    a.each_pair do |key, values|
      results << [key, values]
    end
    
    assert_equal [[:one, [1,2]], [:two, []], [:three, [3]]], results
  end
  
  #
  # to_a test
  #
  
  def test_to_a_returns_the_key_value_pairs_as_an_array
    a = Assignments.new [[:one, [1, 2]], [:two, [3, 4]]]
    assert_equal [[:one, [1, 2]], [:two, [3, 4]]], a.to_a
  end
end