require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema/utils'

class SchemaUtilsTest < Test::Unit::TestCase
  include Tap::Schema::Utils
  
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