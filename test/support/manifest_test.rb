#require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'test/unit'
require 'tap/support/manifest'

class ManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  class ManifestSubclass
    attr_accessor :path_map
    
    def initialize(path_map)
      @path_map = path_map
      super(path_map.collect {|key, value| key})
    end
    
    def each_for(search_path)
      path_map[search_path].each do |key, value|
        yield(key,value)
      end
    end
  end
  
  attr_reader :m
  
  def setup
    @m = ManifestSubclass.new([[:one, 1],[:two, 2],[:three, 3]])  
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
    m = Manifest.new([])
    [[:one, 1],[:two, 2],[:three, 3]].each {|entry| m.entries << entry}
    assert_equal [:one, :two, :three], m.keys
  end
  
  #
  # values test
  #
  
  def test_values_returns_array_of_entries_values
    m = Manifest.new([])
    [[:one, 1],[:two, 2],[:three, 3]].each {|entry| m.entries << entry}
    assert_equal [1,2,3], m.values
  end
  
  #
  # complete? test
  #
  
  def test_complete_is_true_if_search_path_index_equals_search_paths_length
    m = Manifest.new([])
    assert_equal m.search_path_index, m.search_paths.length
    assert m.complete?
    
    m.search_paths << "path"
    assert !m.complete?
  end
  
  #
  # each_for test
  #
  
  def test_each_for_raises_not_implemented_error_if_left_not_implemented
    m = Manifest.new([])
    assert_raise(NotImplementedError) { m.each_for("") }
  end
  
  #
  # store test
  #
  
end