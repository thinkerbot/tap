require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/utils'

class UtilsTest < Test::Unit::TestCase
  include Tap::Test::Utils
  
  def method_path(*paths)
    File.join(__FILE__.chomp('_test.rb'), method_name.to_s, *paths)
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
  
  def test_reference_map_maps_using_path_named_in_file_if_present
    assert_equal "file.txt", File.read(method_path("input/dir.ref"))
    assert_equal "dir", File.read(method_path("input/file.txt.ref"))
    
    # demonstrates that comments are ignored and content is stripped
    assert_equal %Q{# comment
    
   # commment

  path/to/two.txt  #comment

}, File.read(method_path("input/nested.txt.ref"))
    
    assert_equal [
      [method_path("input/dir.ref"), method_path("ref/file.txt"), "file.txt"],
      [method_path("input/file.txt.ref"), method_path("ref/dir"), "dir"],
      [method_path("input/nested.txt.ref"), method_path("ref/path/to/two.txt"), "path/to/two.txt"]
    ], reference_map(method_path('input'), method_path('ref'))
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
  
  #
  # dereference test
  #
  
  def test_dereference_replaces_source_files_with_reference_files_in_block
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/two.txt.ref'))
    assert_equal "two.txt", File.read(method_path('input/three.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/two.txt'))
    assert !File.exists?(method_path('input/three.txt'))
    assert !File.exists?(method_path('input/path'))
    
    was_in_block = false
    dereference(method_path('input'), method_path('ref')) do
      assert !File.exists?(method_path('input/one.txt.ref'))
      assert !File.exists?(method_path('input/two.txt.ref'))
      assert !File.exists?(method_path('input/three.txt.ref'))
      assert !File.exists?(method_path('input/path.ref'))
      
      assert_equal "one", File.read(method_path('input/one.txt'))
      assert_equal "two", File.read(method_path('input/two.txt'))
      assert_equal "two", File.read(method_path('input/three.txt'))
      assert_equal "path/to/one", File.read(method_path('input/path/to/one.txt'))
      assert_equal "path/to/two", File.read(method_path('input/path/to/two.txt'))
      
      was_in_block = true
    end
    
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/two.txt.ref'))
    assert_equal "two.txt", File.read(method_path('input/three.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/two.txt'))
    assert !File.exists?(method_path('input/three.txt'))
    assert !File.exists?(method_path('input/path'))
    
    assert was_in_block
  end
  
  class DereferenceTestError < StandardError
  end
  
  def test_dereference_resets_original_files_even_with_error_in_block
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/path'))
    
    assert_raise(DereferenceTestError) do 
      dereference(method_path('input'), method_path('ref')) do
        raise DereferenceTestError
      end
    end
    
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/path'))
  end
  
  def test_dereference_does_nothing_if_reference_dir_is_nil
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/path'))
    
    was_in_block = false
    dereference(method_path('input'), nil) do
      assert_equal "", File.read(method_path('input/one.txt.ref'))
      assert_equal "", File.read(method_path('input/path.ref'))
      assert !File.exists?(method_path('input/one.txt'))
      assert !File.exists?(method_path('input/path'))
      
      was_in_block = true
    end
    
    assert_equal "", File.read(method_path('input/one.txt.ref'))
    assert_equal "", File.read(method_path('input/path.ref'))
    assert !File.exists?(method_path('input/one.txt'))
    assert !File.exists?(method_path('input/path'))
    
    assert was_in_block
  end
  
end



