require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class InstanceConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetTest
  
  class Receiver
    attr_accessor :key
    
    def initialize
      @key = nil
    end
  end

  attr_reader :c, :r, :cc
  
  def setup
    @r = Receiver.new
    @cc = ClassConfiguration.new(Receiver)
    cc.add(:key)
    @c = InstanceConfiguration.new cc
  end
  
  #
  # documentation test
  #
  
  class Sample
    attr_accessor :key
  end
  
  def test_documentation
    sample = Sample.new

    class_config = ClassConfiguration.new(Sample)
    class_config.add(:key)

    config = InstanceConfiguration.new(class_config)
    config.bind(sample)

    sample.key = 'value'
    assert_equal 'value', config[:key]

    config[:key] = 'another'
    assert_equal 'another', sample.key

    config[:not_a_key] = 'value'
    assert_equal 'value', config[:not_a_key]

    assert_equal({:not_a_key => 'value'}, config.store)
    assert_equal({:key => 'another', :not_a_key => 'value'}, config.to_hash)
  end
  
  #
  # initialization test
  #
  
  def test_initialize
    assert_equal({}, c.store)
    assert_nil c.receiver
  end
  
  #
  # bind test
  #
  
  def test_bind_sets_receiver
    c.bind(r)
    assert_equal r, c.receiver
  end
  
  def test_bind_sets_receiver_with_stored_values
    c[:key] = 1
    c[:not_a_config] = 1
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, c.store)
    
    c.bind(r)
    
    assert_equal 1, r.key
    assert_equal({:not_a_config => 1}, c.store)
  end
  
  def test_bind_does_not_set_configs_without_a_writer
    cc[:key].writer = nil
    c[:key] = 1
    c[:not_a_config] = 1
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, c.store)
    
    c.bind(r)
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, c.store)
  end
  
  def test_bind_raises_error_for_nil_receiver
    assert_raise(ArgumentError) { c.bind(nil) }
  end
  
  def test_bind_returns_self
    assert_equal c, c.bind(r)
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
  # unbind test
  #
  
  def test_unbind_unsets_receiver
    c.bind(r)
    
    assert_equal r, c.unbind
    assert_nil c.receiver
    assert !c.bound?
  end
  
  def test_unbind_sets_store_with_receiver_values
    c.bind(r)
    
    r.key = 1
    assert_equal({}, c.store)
    
    c.unbind
    
    assert_equal 1, r.key
    assert_equal({:key => 1}, c.store)
  end
  
  def test_unbind_does_not_set_configs_without_a_reader
    cc[:key].reader = nil
    c.bind(r)

    r.key = 1
    assert_equal({}, c.store)
    
    c.unbind
    
    assert_equal 1, r.key
    assert_equal({}, c.store)
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
  
  def test_duplicate_class_config_is_the_same_as_parent
    duplicate = c.dup
    assert_equal c.class_config.object_id, duplicate.class_config.object_id
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
  
  def test_get_returns_stored_value_if_config_has_no_reader
    cc[:key].reader = nil
    c.bind(r)
    
    assert_equal nil, c.store[:unmapped]
    c[:unmapped] = "value"
    assert_equal "value", c.store[:unmapped]
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
  
  def test_set_stores_value_in_store_if_config_has_no_writer
    cc[:key].writer = nil
    c.bind(r)

    assert_equal nil, c.store[:unmapped]
    c[:unmapped] = "value"
    assert_equal "value", c.store[:unmapped]
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_is_in_store_or_is_mapped
    c[:key] = 'value'
    c[:another] = 'value'
    
    assert_equal({:key => 'value', :another => 'value'}, c.store)
    assert c.has_key?(:key)
    assert c.has_key?(:another)
    assert !c.has_key?(:not_a_key)
    
    c.bind(r)
    
    assert_equal({:another => 'value'}, c.store)
    assert c.has_key?(:key)
    assert c.has_key?(:another)
    assert !c.has_key?(:not_a_key)
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_yields_each_key_value_pair_stored_in_self
    c[:key] = 'value'
    c[:another] = 'value'
    
    results = {}
    c.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :another => 'value'}, results)
    
    c.bind(r)
    
    r.key = 'VALUE'
    results = {}
    c.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'VALUE', :another => 'value'}, results)
  end
  
  def test_each_pair_pulls_value_from_store_when_config_has_no_reader
    cc[:key].reader = nil
    
    c[:key] = 'value'
    c[:another] = 'value'
    
    results = {}
    c.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :another => 'value'}, results)
    
    c.bind(r)
    
    c.store[:key] = 'VALUE'
    results = {}
    c.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'VALUE', :another => 'value'}, results)
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
    another = InstanceConfiguration.new(ClassConfiguration.new(Receiver))
    
    c[:one] = 'one'
    another[:one] = 'one'
    
    assert(c == another)
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

end