#require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'test/unit'
require 'tap/support/manifest'

class ManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :m
  
  def setup
    @m = Manifest.new([])
  end
  
  #
  # Manifest#normalize test
  #
  
  def test_normalize_replaces_whitespace_with_underscores
    assert_equal "a____b", Manifest.normalize("a \t\n\rb")
  end
  
  def test_normalize_deletes_colons
    assert_equal "ab", Manifest.normalize("a:b")
  end
  
  def test_normalize_stringifies
    assert_equal "ab", Manifest.normalize(:ab)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    m = Manifest.new([])
    assert_equal [], m.entries
  end
  
  #
  # empty? test
  #
  
  def test_manifest_is_empty_if_entries_are_empty
    assert m.entries.empty?
    assert m.empty?
    
    m.entries << :one
    assert !m.empty?
  end
  
  #
  # reset test
  #
  
  def test_reset_clears_entries
    m.entries << :one
    m.reset
    assert_equal [], m.entries  
  end
  
  #
  # each test
  #
  
  def test_each_iterates_over_each_entry_in_self
    m.entries.concat [:one, :two, :three]
    
    results = []
    m.each {|entry| results << entry}
    
    assert_equal [:one, :two, :three], results
  end

  # def test_each_discovers_entries_for_each_search_path_using_entries_for
  #   m = ManifestSubclass.new([[:one, [1]],[:two, [2]],[:three, [3]]])
  #   assert m.entries.empty?
  #   
  #   results = []
  #   m.each {|key, value| results << [key, value]}
  #   
  #   assert_equal [["one_0", 1],["two_0", 2],["three_0", 3]], results
  #   assert_equal [["one_0", 1],["two_0", 2],["three_0", 3]], m.entries
  # end
  # 
  # def test_each_stores_each_for_entries_before_yielding_to_block
  #   m = ManifestSubclass.new([[:one, [1]],[:two, [2,3,4]],[:three, [5]]])
  #   assert m.entries.empty?
  #   
  #   results = []
  #   last_yield_value = m.each do |key, value| 
  #     results << [key, value]
  #     break(value) if key =~ /two/
  #   end
  #   
  #   assert_equal 2, last_yield_value
  #   
  #   assert_equal [["one_0", 1],["two_0", 2]], results
  #   assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4]], m.entries
  # end
  # 
  # def test_each_does_not_duplicate_entries_on_subsequent_each
  #   m = ManifestSubclass.new([[:one, [1]],[:two, [2,3,4]],[:three, [5]]])
  #   assert m.entries.empty?
  #   
  #   results = []
  #   m.each do |key, value|
  #     results << [key, value]
  #     break(value) if key =~ /two/
  #   end
  #   assert_equal [["one_0", 1],["two_0", 2]], results
  #   assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4]], m.entries
  #   
  #   results = []
  #   m.each {|key, value| results << [key, value]}
  #   assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4], ["three_0", 5]], results
  #   assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4], ["three_0", 5]], m.entries
  # end
  
  #
  # minimap test
  #
  
  def test_minimap_returns_an_array_of_mini_key_value_pairs
    m.entries << "path/to/file.txt"
    m.entries << "path/to/another/file.txt"
    m.entries << "path/to/another.txt"
    
    assert_equal [
      ['to/file', "path/to/file.txt"],
      ['another/file', "path/to/another/file.txt"],
      ['another', "path/to/another.txt"]
    ], m.minimap
  end
  
  #
  # minimatch test
  #
  
  def test_minimatch_returns_first_matching_minimized_key
    m.entries << "/path/to/one"
    m.entries << "/path/to/another/one"
    m.entries << "/path/to/two"
    
    assert_equal "/path/to/one", m.minimatch('one')
    assert_equal "/path/to/one", m.minimatch('to/one')
    assert_equal "/path/to/another/one", m.minimatch('another/one')
    assert_equal "/path/to/two", m.minimatch('two')
  end
  
  def test_minimatch_returns_nil_for_no_matching_key
    assert m.entries.empty?
    assert_equal nil, m.minimatch('one')
  end
  
  # def test_minimatch_discovers_entries_as_needed
  #   m = ManifestSubclass.new([
  #     ['/path/to/one', [1]],
  #     ["/path/to/another/one", [2]],
  #     ["/path/to/two", [3]]])
  #   assert m.entries.empty?
  #   
  #   assert_equal ["/path/to/one_0", 1], m['one_0']
  #   assert_equal [["/path/to/one_0", 1]], m.entries
  #   
  #   assert_equal ["/path/to/two_0", 3], m['two_0']
  #   assert_equal [
  #     ["/path/to/one_0", 1],
  #     ["/path/to/another/one_0", 2],
  #     ["/path/to/two_0", 3]
  #   ], m.entries
  # end
end