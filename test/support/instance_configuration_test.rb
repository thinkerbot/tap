require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class InstanceConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetMethods
  
  class Receiver
    attr_accessor :key
  end

  attr_reader :c, :r
  
  def setup
    @r = Receiver.new
    @c = InstanceConfiguration.new :key => :key=
  end
  
  #
  # initialization test
  #
  
  def test_initialize
    assert_equal({}, c.store)
    assert_nil c.receiver
  end
  
  #
  # mapped? test
  #
  
  def test_mapped_is_true_if_key_is_in_mapped_keys
    assert_equal([:key], c.mapped_keys)
    assert c.mapped?(:key)
    assert !c.mapped?('key')
  end
  
  #
  # map_setter test
  #
  
  def test_map_setter_returns_the_setter_method_for_the_mapped_key
    assert_equal :key=, c.map_setter(:key)
  end
  
  def test_map_setter_raises_error_for_unmapped_keys
    assert_raise(ArgumentError) { c.map_setter(:unmapped) }
  end 
  
  #
  # bind test
  #
  
  def test_bind_sets_receiver
    c.bind(r)
    assert_equal r, c.receiver
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
  
  def test_duplicate_map_is_the_same_as_parent
    duplicate = c.dup
    assert_equal c.mapped_keys, duplicate.mapped_keys
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
    c.bind(r)

    assert_equal nil, c[:key]
    r.key = "value"
    assert_equal "value", c[:key]
  end
  
  def test_get_returns_stored_value_if_bound_and_key_is_not_mapped
    c.bind(r)
     
    assert_equal nil, c[:unmapped]
    c.store[:unmapped] = "value"
    assert_equal "value", c[:unmapped]
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
    c.bind(r)
    
    assert_equal nil, r.key
    c[:key] = 'value'
    assert_equal "value", r.key
  end
  
  def test_set_stores_value_in_store_if_bound_and_key_is_not_mapped
    c.bind(r)

    assert_equal nil, c.store[:unmapped]
    c[:unmapped] = "value"
    assert_equal "value", c.store[:unmapped]
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_duplicate_store_when_unbound
    c.store[:one] = 'one'
    c.store[:key] = 'value'
    
    assert_equal({:one => 'one', :key => 'value'}, c.store)
    assert_equal({:one => 'one', :key => 'value'}, c.to_hash)
  end
  
  def test_to_hash_is_not_store
    assert_not_equal c.store.object_id, c.to_hash.object_id
  end
  
  def test_to_hash_returns_hash_with_mapped_and_unmapped_values_when_bound
    c.store[:one] = 'one'
    c.store[:key] = 'value'
    c.bind(r)
    assert_equal({:one => 'one', :key => 'value'}, c.to_hash)
    
    r.key = "VALUE"
    assert_equal({:one => 'one', :key => 'VALUE'}, c.to_hash)
  end
  
  #
  # == test
  #
  
  def test_hash_and_InstanceConfiguration_are_comparable
    assert(c.to_hash == {})
    
    c[:one] = 'one'
    assert(c.to_hash == {:one => 'one'})
  end
  
  def test_InstanceConfigurations_are_compared_on_contents
    another = InstanceConfiguration.new({})
    
    c[:one] = 'one'
    another[:one] = 'one'
    
    assert_not_equal another.mapped_keys, c.mapped_keys
    assert(c == another)
  end
end