require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class InstanceConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetMethods
  
  class Receiver
    attr_accessor :one
  end

  attr_reader :c, :r
  
  def setup
    @r = Receiver.new
    @c = InstanceConfiguration.new
  end
  
  #
  # initialization test
  #
  
  def test_initialize
    assert_equal({}, c.store)
    assert_nil c.receiver
  end
  
  #
  # map test
  #
  
  def test_map_adds_key_to_mapped_keys_and_value_to_store
    assert_equal({}, c.store)
    assert_equal([], c.mapped_keys)
    
    c.map(:key, 'value')
    
    assert_equal({:key => 'value'}, c.store)
    assert_equal([:key], c.mapped_keys)
  end
  
  def test_map_symbolizes_keys
    c.map('key', 'value')
    
    assert_equal({:key => 'value'}, c.store)
    assert_equal([:key], c.mapped_keys)
  end
  
  def test_map_raises_error_when_bound
    c.bind(r)
    assert_raise(RuntimeError) { c.map(:key, nil) }  
  end
  
  #
  # mapped? test
  #
  
  def test_mapped_is_true_if_key_is_in_mapped_keys
    assert !c.mapped?(:key)
    c.map(:key)
    
    assert_equal([:key], c.mapped_keys)
    assert c.mapped?(:key)
    assert !c.mapped?('key')
  end
  
  #
  # unmap test
  #
  
  def test_unmap_removes_key_from_mapped_keys_and_removes_stored_value 
    c.map(:key, 'value')
    assert_equal({:key => 'value'}, c.store)
    assert_equal([:key], c.mapped_keys)
    
    c.unmap(:key)
    
    assert_equal({}, c.store)
    assert_equal([], c.mapped_keys)
  end
  
  def test_unmap_does_not_raise_an_error_for_non_mapped_keys
    assert_nothing_raised { c.unmap(:key) }
  end
  
  def test_unmap_raises_error_when_bound
    c.bind(r)
    assert_raise(RuntimeError) { c.unmap(:key) }  
  end
  
  #
  # map_default test
  #
  
  def test_map_default_returns_mapped_default_value
    c.map(:key)
    assert_equal nil, c.map_default(:key)
    
    c.map(:key, 'value')
    assert_equal 'value', c.map_default(:key)
  end
  
  def test_map_default_may_be_modifed_through_set_when_unbound
    c.map(:key)
    assert_equal nil, c.map_default(:key)
    
    c[:key] = 'value'
    assert_equal 'value', c.map_default(:key)
  end
  
  def test_map_default_raises_error_for_unmapped_keys
    assert_raise(ArgumentError) { c.map_default(:key) }
  end
  
  def test_map_default_duplicates_values
    a = [1,2,3]
    c.map(:array, a)
    
    assert_equal a, c.map_default(:array)
    assert_not_equal a.object_id, c.map_default(:array)
  end
  
  def test_map_default_does_not_duplicate_if_specified
    a = [1,2,3]
    c.map(:array, a)
    
    assert_equal a, c.map_default(:array, false)
    assert_not_equal a.object_id, c.map_default(:array, false)
  end
  
  #
  # map_setter test
  #
  
  def test_map_setter_returns_the_setter_method_for_the_mapped_key
    c.map(:key)
    assert_equal :key=, c.map_setter(:key)
    
    c.map(:key, 'value', 'alt_setter')
    assert_equal :alt_setter, c.map_setter(:key)
  end
  
  def test_map_setter_raises_error_for_unmapped_keys
    assert_raise(ArgumentError) { c.map_setter(:key) }
  end 
  
  #
  # bind test
  #
  
  def test_bind_sets_receiver
    c.bind(r)
    assert_equal r, c.receiver
  end
  
  def test_bind_sets_default_value_in_receiver_for_mapped_keys
    c.map(:one, 'one')
    assert_nil r.one
    c.bind(r)
    assert_equal 'one', r.one
  end
  
  def test_bind_does_not_set_default_values_unless_specified
    c.map(:one, 'one')
    assert_nil r.one
    c.bind(r, false)
    assert_nil r.one
  end
  
  #
  # bound? test
  #
  
  def test_bound_is_true_if_receiver_is_not_nil
    assert !c.bound?
    c.instance_variable_set(:@receiver, r)
    assert c.bound?
    c.instance_variable_set(:@receiver, nil)
    assert !c.bound?
  end
   
  #
  # dup test
  #
  
  def test_duplicate_store_is_separate_from_parent
    duplicate = c.dup
    assert_not_equal c.store.object_id, duplicate.store.object_id
  end
  
  def test_duplicate_is_unbound
    c.bind(r)
    duplicate = c.dup
    assert c.bound?
    assert !duplicate.bound?
  end
  
  def test_duplicate_map_is_separate_from_parent
    duplicate = c.dup
    c.map(:one)
    duplicate.map(:two)
    
    assert_equal [:one], c.mapped_keys
    assert_equal [:two], duplicate.mapped_keys
  end
  
  #
  # get test
  #
  
  def test_get_returns_store_value_if_not_bound
    assert !c.bound?
    
    assert_equal({}, c.store)
    assert_nil c[:key]
    
    c.store[:key] = 'value'
    assert_equal('value', c[:key])
  end
  
  def test_get_returns_mapped_method_on_receiver_if_bound_and_key_is_mapped
    c.map(:one)
    c.bind(r)

    assert_equal nil, c[:one]
    r.one = "value"
    assert_equal "value", c[:one]
  end
  
  def test_get_returns_stored_value_if_bound_and_key_is_not_mapped
    c.bind(r)
     
    assert_equal nil, c[:key]
    c.store[:key] = "value"
    assert_equal "value", c[:key]
  end
  
  #
  # set test
  #
  
  def test_set_stores_value_in_store_if_not_bound
    assert !c.bound?
    assert_equal({}, c.store)
    c[:key] = 'value'
    assert_equal({:key => 'value'}, c.store)
  end
  
  def test_set_send_value_to_mapped_method_on_receiver_if_bound_and_key_is_mapped
    c.map(:one)
    c.bind(r)
    
    assert_equal nil, r.one
    c[:one] = 'value'
    assert_equal "value", r.one
  end
  
  def test_set_stores_value_in_store_if_bound_and_key_is_not_mapped
    c.bind(r)

    assert_equal nil, c.store[:key]
    c[:key] = "value"
    assert_equal "value", c.store[:key]
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_duplicate_store_when_unbound
    c.map(:one, 'one')
    c.store[:key] = 'value'
    
    assert_equal({:one => 'one', :key => 'value'}, c.store)
    assert_equal({:one => 'one', :key => 'value'}, c.to_hash)
  end
  
  def test_to_hash_is_not_store
    assert_not_equal c.store.object_id, c.to_hash.object_id
  end
  
  def test_to_hash_returns_hash_with_mapped_and_unmapped_values_when_bound
    c.map(:one, 'one')
    c.store[:key] = 'value'
    c.bind(r)
    
    r.one = "ONE"
    assert_equal({:one => 'ONE', :key => 'value'}, c.to_hash)
  end
  
  #
  # == test
  #
  
  def test_hash_and_InstanceConfiguration_are_comparable
    assert(c.to_hash == {})
    
    c[:key] = 'value'
    assert(c.to_hash == {:key => 'value'})
  end
  
  def test_InstanceConfigurations_are_compared_on_contents
    another = InstanceConfiguration.new
    
    another.map(:one, 'one')
    c.map(:two, 'two')
    c[:one] = 'one'
    another[:two] = 'two'
    
    assert_not_equal another.mapped_keys, c.mapped_keys
    assert(c == another)
  end
end