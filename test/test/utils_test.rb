require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/utils'

class UtilsTest < Test::Unit::TestCase
  include Tap::Test::Utils
  
  def method_path(*paths)
    File.join(__FILE__.chomp('_test.rb'), method_name, *paths)
  end
  
  #
  # reference_map test
  #
  
  def test_reference_map_documentation
    assert_equal [
      [method_path("input/dir.ref"), method_path("ref/dir")],
      [method_path("input/one.txt.ref"), method_path("ref/one.txt")],
      [method_path("input/two.txt.ref"), method_path("ref/path/to/two.txt")]
    ], reference_map(method_path('input'), method_path('ref'))
  end
  
  def test_reference_map_returns_a_list_of_ref_files_under_source_dir_mapped_to_ref_dir
    assert_equal([
      [method_path("input/one.txt.ref"), method_path("ref/one.txt")],
      [method_path("input/two.ref"), method_path("ref/two")],
      [method_path("input/nested/one.txt.ref"), method_path("ref/nested/one.txt")],
      [method_path("input/nested/two.ref"), method_path("ref/nested/two")]
    ].sort, reference_map(method_path('input'), method_path('ref')).sort)
  end
  
  def test_reference_map_globs_for_files_with_ref_extname
    assert_equal [[method_path("input/one.txt.ref"), method_path("ref/one.txt")]], reference_map(method_path('input'), method_path('ref'))
    assert_equal [[method_path("input/two.txt"), method_path("ref/two")]], reference_map(method_path('input'), method_path('ref'), ".txt")
  end
  
  def test_reference_map_globs_for_reference_files_matching_basename_if_default_map_does_not_exist
    assert_equal [
      [method_path("input/one.txt.ref"), method_path("ref/nested/one.txt")],
      [method_path("input/two.ref"), method_path("ref/nested/two")],
      [method_path("input/nested/three.txt.ref"), method_path("ref/three.txt")]
    ].sort, reference_map(method_path('input'), method_path('ref')).sort
  end
  
  def test_reference_map_raises_error_if_multiple_reference_files_match_path
    assert_raise(ArgumentError) { reference_map(method_path('input'), method_path('ref')) }
  end
  
  def test_reference_map_raises_error_if_no_reference_files_match_path
    assert_raise(ArgumentError) { reference_map(method_path('input'), method_path('ref')) }
  end

end



