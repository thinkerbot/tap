require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/aggregator'
require 'tap/support/audit'

class AggregatorTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :audit, :aggregator
 
  def setup
    @audit = Audit.new(:a, 'a')
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
  # clear test
  #
  
  def test_clear_clears_store_of_audits 
    aggregator.store(audit)
    aggregator.store(audit)
    assert_equal({:a => [audit, audit]}, aggregator.to_hash)
    
    aggregator.clear
    assert_equal({}, aggregator.to_hash)
  end
  
  def test_clear_returns_current_audits_as_a_hash
    aggregator.store(audit)
    
    assert_equal({:a => [audit]}, aggregator.to_hash)
    assert_equal({:a => [audit]}, aggregator.clear)
  end
  
  #
  # size test
  #
  
  def test_size_returns_the_total_number_of_audits_in_self
    a = Audit.new(:a, 'a')
    b = Audit.new(:b, 'b')
    
    aggregator.store(a)
    aggregator.store(a)
    aggregator.store(b)
    
    assert_equal 3, aggregator.size
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_size_is_zero
    assert_equal 0, aggregator.size
    assert aggregator.empty?
    
    aggregator.store(audit)
    
    assert_equal 1, aggregator.size
    assert !aggregator.empty?
  end
  
  #
  # store test
  #
  
  def test_store_appends_audit_to_array_keyed_by_audit_key
    a = Audit.new(:a, 'a')
    aggregator.store(a)
    assert_equal({:a => [a]}, aggregator.to_hash)
    
    aggregator.store(a)
    assert_equal({:a => [a, a]}, aggregator.to_hash)
    
    b = Audit.new(:b, 'b')
    aggregator.store(b)
    assert_equal({:a => [a, a], :b => [b]}, aggregator.to_hash)
  end
  
  #
  # retrieve test
  #
  
  def test_retrieve_returns_audits_for_key
    aggregator.store(audit)
    aggregator.store(audit)
    assert_equal [audit, audit], aggregator.retrieve(audit.key)
  end
  
  def test_retrieve_returns_nil_for_unknown_key
    assert_nil aggregator.retrieve(:unknown)
  end
  
  #
  # retrieve_all test
  #
  
  def test_retrieve_all_returns_concatenated_arrays_for_keys
    a = Audit.new(:a, 'a')
    aggregator.store(a)
    aggregator.store(a)
    
    b = Audit.new(:b, 'b')
    aggregator.store(b)
    
    assert_equal [a,a], aggregator.retrieve_all(:a)
    assert_equal [b], aggregator.retrieve_all(:b)
    assert_equal [a,a,b], aggregator.retrieve_all(:a, :b)
    assert_equal [b,a,a], aggregator.retrieve_all(:b, :a)
    assert_equal [a,a,b], aggregator.retrieve_all(:a, :unknown, :b)
  end
  
  def test_retrieve_all_returns_empty_array_for_unknown_keys
    assert_equal [], aggregator.retrieve_all(:a, :unknown, :b)
  end
end