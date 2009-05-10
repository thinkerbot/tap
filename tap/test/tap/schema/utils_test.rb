require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema/utils'

class SchemaUtilsTest < Test::Unit::TestCase
  include Tap::Schema::Utils
  
  def references
    {:ref => lambda { 'value' }}
  end
  
  #
  # symbolize test
  #
  
  def test_symbolize_symbolizes_keys_of_hash
    hash = {'str' => 1, :sym => 2}
    assert_equal({:str => 1, :sym => 2}, symbolize(hash))
  end
  
  def test_symbolize_dereferences_references
    hash = {'@key' => :ref }
    assert_equal({:key => 'value'}, symbolize(hash))
  end
  
  def test_symbolize_returns_non_hash_values
    assert_equal([1,2,3], symbolize([1,2,3]))
  end
  
  def test_symbolize_raises_error_for_conflict
    hash = {'str' => 1, :str => 2}
    err = assert_raises(RuntimeError) { symbolize(hash)}
    assert_equal "symbolize conflict: #{hash.inspect} (:str)", err.message
  end
  
  #
  # stringify test
  #
  
  def test_stringify_stringifies_keys_of_hash
    hash = {'str' => 1, :sym => 2}
    assert_equal({'str' => 1, 'sym' => 2}, stringify(hash))
  end
  
  def test_stringify_references_reference_values
    hash = {:key => 'value'}
    assert_equal({'@key' => :ref }, stringify(hash))
  end
  
  def test_stringify_returns_non_hash_values
    assert_equal([1,2,3], stringify([1,2,3]))
  end
  
  def test_stringify_raises_error_for_conflict
    hash = {'str' => 1, :str => 2}
    err = assert_raises(RuntimeError) { stringify(hash)}
    assert_equal "stringify conflict: #{hash.inspect} (\"str\")", err.message
  end
  
  #
  # dehashify test
  #
  
  def test_dehashify_collects_the_values_of_hash_by_sorted_key
    letters = ('a'..'z').to_a
    caps = ('A'..'Z').to_a
    
    hash = {}
    letters.each {|letter| hash[letter] = letter.upcase}
    
    values = []
    hash.each_pair {|key, value| values << value}
    assert values != caps
    
    assert_equal caps, dehashify(hash)
  end
  
  def test_dehashify_returns_non_hash_values
    assert_equal([1,2,3], dehashify([1,2,3]))
  end
  
  #
  # hashify test
  #
  
  def test_hashify_returns_a_hash_of_each_element_by_index
    assert_equal({0 => 'a', 1 => 'b', 2 => 'c'}, hashify(%w{a b c}))
  end
  
  def test_hashify_returns_hashes
    hash = {:key => 'value'}
    assert_equal hash, hashify(hash)
  end
end