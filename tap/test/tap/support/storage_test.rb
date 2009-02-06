require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/storage'

class StorageTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :storage
 
  def setup
    @storage = Storage.new
  end
  
  #
  # documentatio
  #
  
  def test_storage_documentation
    storage = Storage.new
    storage.store(:key, 'value')
    assert_equal "value", storage.fetch(:key)
    assert_equal({:key => 'value'}, storage.to_hash)
  end
  
  #
  # store/fetch test
  #
  
  def test_store_stores_value_by_key_and_fetch_fetches_value_by_key
    storage.store(:key, 'value')
    assert_equal 'value', storage.fetch(:key)
  end
  
  def test_store_overwrites_existing_value
    storage.store(:key, 'a')
    storage.store(:key, 'b')
    assert_equal 'b', storage.fetch(:key)
  end
  
  def test_fetch_returns_nil_if_no_such_key_exists
    assert_equal nil, storage.fetch(:key)
  end
  
  #
  # remove test
  #
  
  def test_remove_removes_value_for_key
    storage.store(:key, 'value')
    storage.remove(:key)
    assert_equal nil, storage.fetch(:key)
  end
  
  def test_remove_returns_current_value_for_key
    storage.store(:key, 'value')
    assert_equal "value", storage.remove(:key)
    assert_equal nil, storage.remove(:key)
  end
  
  #
  # key? test
  #
  
  def test_key_returns_true_if_self_has_stored_a_value_for_key
    assert_equal false, storage.key?(:key)
    storage.store(:key, 'value')
    assert_equal true, storage.key?(:key)
  end
  
  def test_key_is_true_for_nil_values
    storage.store(:key, nil)
    assert_equal true, storage.key?(:key)
  end
  
  #
  # clear test
  #
  
  def test_clear_clears_self_of_values
    storage.store(:key, 'value')
    storage.clear
    assert_equal nil, storage.fetch(:key)
  end
  
  def test_clear_returns_existing_key_value_pairs
    storage.store(:key, 'value')
    assert_equal({:key => 'value'}, storage.clear)
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_existing_values_as_a_hash
    storage.store(:key, 'value')
    
    result = storage.to_hash
    assert result.kind_of?(Hash)
    assert_equal({:key => 'value'}, result)
  end
end