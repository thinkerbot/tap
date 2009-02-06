require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/storage'

class StorageTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :storage
 
  def setup
    @storage = Storage.new
  end
  
  #
  # documentation
  #
  
  def test_storage_documentation
    storage = Storage.new
    storage[:key] = 'value'
    assert_equal "value", storage[:key]
    assert_equal({:key => 'value'}, storage.to_hash)
    
    id = storage.store('VALUE')
    assert_equal "VALUE", storage[id] 
    
    assert !storage.has_key?(:unknown)
    assert_equal "default", storage.fetch(:unknown) { 'default' }
    assert_equal "default", storage[:unknown]
  end
  
  #
  # AGET/ASET test
  #
  
  def test_ASET_stores_value_by_key_and_fetch_fetches_value_by_key
    storage[:key] = 'value'
    assert_equal 'value', storage[:key]
  end
  
  def test_ASET_overwrites_existing_value
    storage[:key] = 'a'
    storage[:key] = 'b'
    assert_equal 'b', storage[:key]
  end
  
  def test_AGET_returns_nil_if_no_such_key_exists
    assert_equal nil, storage[:key]
  end
  
  #
  # store test
  #
  
  def test_store_stores_value_by_a_random_integer_key_and_returns_the_key
    id = storage.store('value')
    assert id.kind_of?(Integer)
    assert_equal 'value', storage[id]
  end
  
  def test_store_stores_value_every_time_it_is_called
    a = storage.store('value')
    b = storage.store('value')
    assert a != b
    assert_equal({a => 'value', b => 'value'}, storage.to_hash)
  end
  
  #
  # fetch test
  #
  
  def test_fetch_returns_the_value_stored_for_key
    storage[:key] = 'value'
    assert_equal 'value', storage.fetch(:key)
  end
  
  def test_fetch_returns_nil_if_no_value_is_stored_for_key
    assert_equal nil, storage.fetch(:key)
    assert !storage.has_key?(:key)
  end
  
  def test_fetch_evaluates_and_stores_block_return_if_no_value_is_stored_for_key
    assert_equal 'default', storage.fetch(:key) { 'default' }
    assert_equal 'default', storage[:key]
  end
  
  #
  # remove test
  #
  
  def test_remove_removes_value_for_key
    storage[:key] = 'value'
    storage.remove(:key)
    assert_equal nil, storage[:key]
  end
  
  def test_remove_returns_current_value_for_key
    storage[:key] = 'value'
    assert_equal "value", storage.remove(:key)
    assert_equal nil, storage.remove(:key)
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_returns_true_if_self_has_stored_a_value_for_key
    assert_equal false, storage.has_key?(:key)
    storage[:key] = 'value'
    assert_equal true, storage.has_key?(:key)
  end
  
  def test_has_key_is_true_for_nil_values
    storage[:key] = nil
    assert_equal true, storage.has_key?(:key)
  end
  
  #
  # clear test
  #
  
  def test_clear_clears_self_of_values
    storage[:key] = 'value'
    storage.clear
    assert_equal nil, storage.fetch(:key)
  end
  
  def test_clear_returns_existing_key_value_pairs
    storage[:key] = 'value'
    assert_equal({:key => 'value'}, storage.clear)
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_existing_values_as_a_hash
    storage[:key] = 'value'
    
    result = storage.to_hash
    assert result.kind_of?(Hash)
    assert_equal({:key => 'value'}, result)
  end
end