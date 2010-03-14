require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/env/path'
require 'tap/test'

class PathTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  
  Path = Tap::Env::Path
  attr_reader :path
  
  def setup
    super
    @path = Path.new(method_root.path)
  end
  
  #
  # initialize test
  #
  
  def test_initialize_splits_and_expands_map
    path = Path.new(method_root.path, :array => ['/a/b', 'c'], :string => '/e/f:g')
    assert_equal({
      :array => ['/a/b', method_root.path('c')],
      :string => ['/e/f', method_root.path('g')]
    }, path.map)
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_type_joined_to_base_for_unspecified_mappings
    assert path.map.empty?
    assert_equal [method_root.path(:type)], path[:type]
  end
  
  def test_AGET_returns_mapped_paths_for_named_type
    path.map[:type] = ['/a/b']
    assert_equal ['/a/b'], path[:type]
  end
  
  #
  # ASET test
  #
  
  def test_ASET_sets_path_for_type_expanding_relative_to_base_as_necessary
    path[:type] = ['/a/b', 'c/d']
    assert_equal({:type => ['/a/b', method_root.path('c/d')]}, path.map)
  end
  
  def test_ASET_splits_and_arrayifies_string_inputs
    path[:type] = '/a/b:c/d'
    assert_equal({:type => ['/a/b', method_root.path('c/d')]}, path.map)
  end
end