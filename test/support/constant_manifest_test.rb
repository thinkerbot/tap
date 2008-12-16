require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/constant_manifest'

class ConstantManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_file_test
  
  attr_reader :m
  
  def setup
    super
    @m = ConstantManifest.new('attr')
  end
  
  def cleanup
    Tap::Test::Utils.clear_dir(method_root.root)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    m = ConstantManifest.new('attr')
    assert_equal 'attr', m.const_attr
    assert_equal [], m.search_paths
    assert_equal 0, m.search_path_index
    assert_equal 0, m.path_index
  end
  
  #
  # register test
  #
  
  def test_register_globs_for_files_under_dir_and_adds_these_to_search_paths
    a = method_root.prepare('a.txt') {}
    b = method_root.prepare('b.txt') {}
    c = method_root.prepare('c.rb') {}

    m.register(method_root.root, "*.txt")
    assert_equal [[method_root.root, [a,b]]], m.search_paths
    
    m.register(method_root.root, "*.rb")
    assert_equal [
      [method_root.root, [a,b]],
      [method_root.root, [c]]
    ], m.search_paths
  end
  
  def test_register_returns_self
    assert_equal m, m.register('dir', '*.txt')
  end
  
  #
  # build test
  #
  
  def test_build_searches_for_constants_with_const_attr_along_paths
    a = method_root.prepare('a.txt') {|file| file << "# A::attr" }
    b = method_root.prepare('b.txt') {|file| file << "# B::attr\n# Nested::B::attr" }
    c = method_root.prepare('c.txt') {|file| file << "# C::another" }
    
    m.register(method_root.root, "*.txt")
    m.build
    
    assert_equal [["A", a], ["B", b], ["Nested::B", b]], m.entries.collect {|const| [const.name, const.require_path]}
  end
  
  def test_build_infers_default_const_name_from_relative_filepath
    a = method_root.prepare('a.txt') {|file| file << "# ::attr" }
    b = method_root.prepare('path/to/b.txt') {|file| file << "# ::attr" }
    
    m.register(method_root.root, "**/*.txt")
    m.build
    
    assert_equal [["A", a], ["Path::To::B", b]], m.entries.collect {|const| [const.name, const.require_path]}
  end
  
  def test_build_returns_self
    assert_equal m, m.build
  end
  
  #
  # built? test
  #
  
  def test_built_returns_true_if_search_path_index_equals_search_paths_length
    assert_equal m.search_paths.length, m.search_path_index
    assert m.built?
    
    m.search_paths << ['path', []]
    assert !m.built?
  end
  
  #
  # reset test
  #
  
  def test_reset_sets_search_path_index_and_path_index_to_zero
    m.instance_variable_set(:@search_path_index, 1)
    m.instance_variable_set(:@path_index, 1)
    
    assert_equal 1, m.search_path_index
    assert_equal 1, m.path_index
    
    m.reset
    
    assert_equal 0, m.search_path_index
    assert_equal 0, m.path_index
  end
  
  def test_reset_clears_entries
    m.entries << :one
    m.reset
    assert_equal [], m.entries
  end
  
  def test_reset_returns_self
    assert_equal m, m.reset
  end
  
  #
  # each test
  #
  
  def test_each_discovers_constants_with_const_attr_along_paths
    a = method_root.prepare('a.txt') {|file| file << "# A::attr" }
    b = method_root.prepare('b.txt') {|file| file << "# B::attr\n# Nested::B::attr" }
    c = method_root.prepare('c.txt') {|file| file << "# C::another" }
    m.register(method_root.root, "*.txt")
    
    assert m.entries.empty?
    
    results = []
    m.each {|const| results << const.name }
    
    assert_equal ["A", "B", "Nested::B"], results
    assert_equal [["A", a], ["B", b], ["Nested::B", b]], m.entries.collect {|const| [const.name, const.require_path]}
  end
  
  def test_each_stores_new_entries_before_yielding_to_block
    a = method_root.prepare('a.txt') {|file| file << "# A::attr" }
    b = method_root.prepare('b.txt') {|file| file << "# B::attr\n# Nested::B::attr" }
    c = method_root.prepare('c.txt') {|file| file << "# C::attr" }
    m.register(method_root.root, "*.txt")
    
    results = []
    last_value = m.each do |const| 
      results << const.name
      break(const) if const.name =~ /B/
    end
    
    assert_equal 'B', last_value.name
    assert_equal ["A", "B"], results
    assert_equal [["A", a], ["B", b], ["Nested::B", b]], m.entries.collect {|const| [const.name, const.require_path]}
  end
  
  def test_each_does_not_duplicate_entries_on_subsequent_each
    a = method_root.prepare('a.txt') {|file| file << "# A::attr" }
    b = method_root.prepare('b.txt') {|file| file << "# B::attr\n# Nested::B::attr" }
    c = method_root.prepare('c.txt') {|file| file << "# C::attr" }
    m.register(method_root.root, "*.txt")

    results = []
    m.each do |const| 
      results << const.name
      break if const.name =~ /B/
    end
    assert_equal ["A", "B"], results
    assert_equal [["A", a], ["B", b], ["Nested::B", b]], m.entries.collect {|const| [const.name, const.require_path]}
    
    results = []
    m.each {|const| results << const.name }
    assert_equal ["A", "B", "Nested::B", "C"], results
    assert_equal [["A", a], ["B", b], ["Nested::B", b], ["C", c]], m.entries.collect {|const| [const.name, const.require_path]}
  end
end