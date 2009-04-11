require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/aggregator'
require 'tap/app/audit'

class AggregatorTest < Test::Unit::TestCase
  Audit = Tap::App::Audit
  Aggregator = Tap::App::Aggregator
  
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
    assert_equal [a, b], agg.audits(:key)
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
  # audits test
  #
  
  def test_audits_returns_concatenated_arrays_for_keys
    a = Audit.new(:a, 'a')
    aggregator.store(a)
    aggregator.store(a)
    
    b = Audit.new(:b, 'b')
    aggregator.store(b)
    
    assert_equal [a,a], aggregator.audits(:a)
    assert_equal [b], aggregator.audits(:b)
    assert_equal [a,a,b], aggregator.audits(:a, :b)
    assert_equal [b,a,a], aggregator.audits(:b, :a)
    assert_equal [a,a,b], aggregator.audits(:a, :unknown, :b)
  end
  
  def test_audits_returns_empty_array_for_unknown_keys
    assert_equal [], aggregator.audits(:a, :unknown, :b)
  end
  
  #
  # results test
  #
  
  def test_results_returns_current_values_of__results
    a1 = Audit.new(:t1, 1)
    a2 = Audit.new(:t2, 2)
    
    aggregator.store a1
    aggregator.store a2
    assert_equal [1], aggregator.results(:t1)
    assert_equal [2, 1], aggregator.results(:t2, :t1)
    assert_equal [1, 1], aggregator.results(:t1, :t1)
  end
  
  #
  # YAML test
  #
  
  def test_aggregator_serializes_and_deserializes_cleanly
    a1 = Audit.new(:t1, 1)
    a2 = Audit.new(:t1, 2)
    a3 = Audit.new(:t2, 3)
    
    aggregator.store a1
    aggregator.store a2
    aggregator.store a3
    
    str = YAML.dump(aggregator)
    d = YAML.load(str)
    
    assert_equal [1,2], d.results(:t1)
    assert_equal [3, 1, 2], d.results(:t2, :t1)
    assert_equal [1, 2, 1, 2], d.results(:t1, :t1)
  end
end