#require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'test/unit'
require 'tap/support/manifest'

class ManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  class ManifestSubclass < Manifest
    attr_accessor :path_map
    
    def initialize(entries)
      @path_map = {}
      keys = entries.collect do |key, value|
        @path_map[key] = value
        key
      end
      super(keys)
    end
    
    def entries_for(search_path)
      entries = []
      path_map[search_path].each_with_index do |value, index|
        entries << ["#{search_path}_#{index}", value]
      end
      entries
    end
  end
  
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
    assert_equal [], m.search_paths
    assert_equal 0, m.search_path_index
  end
  
  #
  # keys test
  #
  
  def test_keys_returns_array_of_entries_keys
    [[:one, 1],[:two, 2],[:three, 3]].each {|entry| m.entries << entry}
    assert_equal [:one, :two, :three], m.keys
  end
  
  #
  # values test
  #
  
  def test_values_returns_array_of_entries_values
    [[:one, 1],[:two, 2],[:three, 3]].each {|entry| m.entries << entry}
    assert_equal [1,2,3], m.values
  end
  
  #
  # reset test
  #
  
  def test_reset_clears_entries_and_resets_search_path_index_to_zero
    m = ManifestSubclass.new([[:one, [1]],[:two, [2]],[:three, [3]]])
    m.build
    
    assert !m.entries.empty?
    assert_not_equal 0, m.search_path_index
    
    m.reset
    
    assert m.entries.empty?
    assert_equal 0, m.search_path_index
  end
  
  #
  # build test
  #
  
  def test_build_returns_self
    assert_equal m, m.build
  end
  
  def test_identifies_all_entries_from_search_paths
    m = ManifestSubclass.new([[:one, [1]],[:two, [2]],[:three, [3]]])
    assert m.entries.empty?

    m.build
    assert_equal [["one_0", 1],["two_0", 2],["three_0", 3]], m.entries
  end
  
  #
  # built? test
  #
  
  def test_built_is_true_if_search_path_index_equals_search_paths_length
    assert_equal m.search_path_index, m.search_paths.length
    assert m.built?
    
    m.search_paths << "path"
    assert !m.built?
  end
  
  #
  # entries_for test
  #
  
  def test_entries_for_raises_not_implemented_error_if_left_not_implemented
    assert_raise(NotImplementedError) { m.entries_for("") }
  end
  
  #
  # store test
  #
  
  def test_store_adds_key_value_pair_to_entries_as_an_array
    assert m.entries.empty?
    
    m.store('key', 'value')
    assert_equal [['key', 'value']], m.entries
  end
  
  def test_store_normalizes_key_using_Manifest_normalize
    m.store('C:/K ey', 'value')
    m.store(:key, 'value')

    assert_equal [['c/k_ey', 'value'], ['key', 'value']], m.entries
  end
  
  def test_store_raises_error_if_key_is_already_in_entries_with_a_different_value
    m.entries << ['key', 'value']
    assert_raise(Manifest::ManifestConflict) { m.store('key', 'another') }
    assert_raise(Manifest::ManifestConflict) { m.store('KeY', 'another') }
  end
  
  def test_store_does_nothing_if_key_is_already_assigned_to_value_in_entries
    m.entries << ['one', 1]
    m.entries << ['two', 2]
    m.entries << ['three', 3]
    assert_nothing_raised { m.store('two', 2) }
    assert_equal [['one', 1],['two', 2],['three', 3]], m.entries
  end
  
  def test_store_returns_existing_entry
    m.entries << ['one', 1]
    entry = m.store('one', 1)
    assert_equal m.entries[0].object_id, entry.object_id
  end
  
  def test_store_returns_new_entry
    entry = m.store('one', 1)
    assert_equal m.entries[0].object_id, entry.object_id
  end
  
  #
  # each test
  #
  
  def test_each_iterates_over_each_entry_in_self
    m.entries << [:one, 1]
    m.entries << [:two, 2]
    m.entries << [:three, 3]
    
    results = []
    m.each {|key, value| results << [key, value]}
    
    assert_equal [[:one, 1],[:two, 2],[:three, 3]], results
  end

  def test_each_discovers_entries_for_each_search_path_using_entries_for
    m = ManifestSubclass.new([[:one, [1]],[:two, [2]],[:three, [3]]])
    assert m.entries.empty?
    
    results = []
    m.each {|key, value| results << [key, value]}
    
    assert_equal [["one_0", 1],["two_0", 2],["three_0", 3]], results
    assert_equal [["one_0", 1],["two_0", 2],["three_0", 3]], m.entries
  end
  
  def test_each_stores_each_for_entries_before_yielding_to_block
    m = ManifestSubclass.new([[:one, [1]],[:two, [2,3,4]],[:three, [5]]])
    assert m.entries.empty?
    
    results = []
    last_yield_value = m.each do |key, value| 
      results << [key, value]
      break(value) if key =~ /two/
    end
    
    assert_equal 2, last_yield_value
    
    assert_equal [["one_0", 1],["two_0", 2]], results
    assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4]], m.entries
  end
  
  def test_each_does_not_duplicate_entries_on_subsequent_each
    m = ManifestSubclass.new([[:one, [1]],[:two, [2,3,4]],[:three, [5]]])
    assert m.entries.empty?
    
    results = []
    m.each do |key, value|
      results << [key, value]
      break(value) if key =~ /two/
    end
    assert_equal [["one_0", 1],["two_0", 2]], results
    assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4]], m.entries
    
    results = []
    m.each {|key, value| results << [key, value]}
    assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4], ["three_0", 5]], results
    assert_equal [["one_0", 1],["two_0", 2],["two_1", 3], ["two_2", 4], ["three_0", 5]], m.entries
  end
  
  #
  # minimize test
  #
  
  def test_minimize_returns_an_array_of_mini_key_value_pairs
    m.entries << ["path/to/file.txt", 1]
    m.entries << ["path/to/another/file.txt", 2]
    m.entries << ["path/to/another.txt", 3]
    
    assert_equal [['to/file', 1],['another/file', 2],['another', 3]], m.minimize
  end
end