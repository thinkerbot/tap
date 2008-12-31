require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/aggregator'
require 'tap/support/audit'

class AggregatorTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :aggregator
 
  def setup
    @aggregator = Aggregator.new
  end
  
  def test_aggregator_documentation
    a = Audit.new(:key, 'a')
    b = Audit.new(:key, 'b')

    agg = Aggregator.new
    agg.store(a)
    agg.store(b)
    assert_equal [a, b], agg.retrieve(:key)
  end
  
  #
  # store test
  #
  
  def test_store_appends_audit_to_array_keyed_by_key
    a = Audit.new(:a, 'a')
    assert_equal :a, a.key
    
    aggregator.store(a)
    assert_equal({:a => [a]}, aggregator.to_hash)
    
    aggregator.store(a)
    assert_equal({:a => [a, a]}, aggregator.to_hash)
    
    b = Audit.new(:b, 'b')
    assert_equal :b, b.key
    
    aggregator.store(b)
    assert_equal({:a => [a, a], :b => [b]}, aggregator.to_hash)
  end
  
  #
  # clear test
  #
  
  def test_clear
    a = Audit.new(:a, 'a')
    
    aggregator.store(a)
    aggregator.store(a)
    assert_equal({:a => [a, a]}, aggregator.to_hash)
    
    aggregator.clear
    assert_equal({}, aggregator.to_hash)
  end
  
  #
  # retrieve test
  #
  
  def test_retrieve_returns_array_for_source
    a = Audit.new(:a, 'a')
    
    aggregator.store(a)
    aggregator.store(a)
    assert_equal({:a => [a, a]}, aggregator.to_hash)
    
    assert_equal [a,a], aggregator.retrieve(:a)
  end
  
  def test_retrieve_returns_nil_for_unknown_source
    assert_nil aggregator.retrieve(:unknown)
  end
  
  #
  # retrieve_all test
  #
  
  def test_retrieve_all_returns_concatenated_arrays_for_sources
    a = Audit.new(:a, 'a')
    
    aggregator.store(a)
    aggregator.store(a)
    
    b = Audit.new(:b, 'b')
    aggregator.store(b)
    
    assert_equal({:a => [a, a], :b => [b]}, aggregator.to_hash)
    
    assert_equal [a,a], aggregator.retrieve_all(:a)
    assert_equal [b], aggregator.retrieve_all(:b)
    assert_equal [a,a,b], aggregator.retrieve_all(:a, :b)
    assert_equal [b,a,a], aggregator.retrieve_all(:b, :a)
    
    assert_equal [a,a,b], aggregator.retrieve_all(:a, :unknown, :b)
  end
  
  def test_retrieve_all_returns_empty_array_for_all_unknown_sources
    assert_equal [], aggregator.retrieve_all(:a, :unknown, :b)
  end
end