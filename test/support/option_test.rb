require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class OptionTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :o
  def setup
    @o = Option.new('name')
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    o = Option.new('name')
    assert_equal 'name', o.name
    assert_nil o.default
    assert_equal :mandatory, o.arg
    
    o = Option.new('name', 'default', :optional)
    assert_equal 'name', o.name
    assert_equal 'default', o.default
    assert_equal :optional, o.arg
  end
  
  #
  # default= test
  #
  
  def test_set_default_sets_default
    assert_nil o.default
    o.default = 1
    assert_equal 1, o.default
  end
  
  def test_set_default_sets_duplicable_to_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym].each do |non_duplicable_default|
      o.default = non_duplicable_default
      assert !o.duplicable
    end
  end
  
  def test_set_default_sets_duplicable_to_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_default|
      o.default = duplicable_default
      assert o.duplicable
    end
  end
  
  def test_set_default_freezes_object
    a = []
    assert !a.frozen?
    o.default = a
    assert a.frozen?
  end
  
  def test_non_freezable_objects_are_not_frozen
    o.default = 1
    assert !o.default.frozen?
    
    o.default = :sym
    assert !o.default.frozen?
    
    o.default = nil
    assert !o.default.frozen?
  end
  
  #
  # default test
  #

  def test_default_returns_default
    assert_equal nil, o.default
    
    o.default = 'value'
    assert_equal 'value', o.default
  end
  
  def test_default_returns_duplicate_values
    a = [1,2,3]
    o.default = a
  
    assert_equal a, o.default
    assert_not_equal a.object_id, o.default.object_id
  end
  
  def test_default_does_not_duplicate_if_specified
    a = [1,2,3]
    o.default = a
  
    assert_equal a, o.default(false)
    assert_equal a.object_id, o.default(false).object_id
  end
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_all_attributes_are_equal
    option = Option.new('name')
    another = Option.new('name')
    assert option == another
    
    option = Option.new('name')
    another = Option.new('alt')
    assert option != another
    
    option = Option.new('name', 1)
    another = Option.new('name', 2)
    assert option != another
    
    option = Option.new('name', 1, :mandatory)
    another = Option.new('name', 1, :optional)
    assert option != another
  end
  
end