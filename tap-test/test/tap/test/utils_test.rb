require File.expand_path('../../../test_helper.rb', __FILE__) 
require 'tap/test/utils'

class UtilsTest < Test::Unit::TestCase
  include Tap::Test::Utils
  
  def method_path(*paths)
    File.expand_path File.join(__FILE__.chomp('_test.rb'), method_name.to_s, *paths)
  end
  
  #
  # reference_map test
  #
  
  def test_reference_map_documentation
    assert_equal 'path/to/two.txt', File.read(method_path("input/two.txt.ref")) 
    
    assert_equal [
      [method_path("input/dir.ref"), method_path("ref/dir")],
      [method_path("input/one.txt.ref"), method_path("ref/one.txt")],
      [method_path("input/two.txt.ref"), method_path("ref/path/to/two.txt")]
    ], reference_map(method_path('input'), method_path('ref'))
    
    assert_raises(DereferenceError) { reference_map(method_path('input'), method_path('ref'), '**/*.txt') }
  end
  
  def test_reference_map_returns_a_list_of_ref_files_under_source_dir_mapped_to_ref_dir
    assert_equal([
      [method_path("input/nested/one.txt.ref"), method_path("ref/nested/one.txt")],
      [method_path("input/nested/two.ref"), method_path("ref/nested/two")],
      [method_path("input/one.txt.ref"), method_path("ref/one.txt")],
      [method_path("input/two.ref"), method_path("ref/two")]
    ], reference_map(method_path('input'), method_path('ref')))
  end
  
  def test_reference_map_maps_using_path_named_in_file_if_present
    assert_equal "file.txt", File.read(method_path("input/dir.ref"))
    assert_equal "dir", File.read(method_path("input/file.txt.ref"))
    assert_equal %Q{# comment
    
   # commment

  path/to/two.txt  #comment

}, File.read(method_path("input/nested.txt.ref"))
    
    assert_equal [
      [method_path("input/dir.ref"), method_path("ref/file.txt")],
      [method_path("input/file.txt.ref"), method_path("ref/dir")],
      [method_path("input/nested.txt.ref"), method_path("ref/path/to/two.txt")]
    ], reference_map(method_path('input'), method_path('ref'))
  end
  
  def test_reference_map_raises_error_if_no_reference_file_is_found
    assert_raises(DereferenceError) { reference_map(method_path('input'), method_path('ref')) }
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
    
    assert_raises(DereferenceTestError) do 
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
  
  #
  # template test
  #
  
  def test_template_templates_the_specified_files_for_the_duration_of_the_block
    assert_equal "<%= one %> was templated", File.read(method_path('one.txt'))
    assert_equal "<%= two %> was templated", File.read(method_path('two.txt'))

    was_in_block = false
    template([method_path('one.txt'), method_path('two.txt')], :one => 1, :two => 2) do
      assert_equal "1 was templated", File.read(method_path('one.txt'))
      assert_equal "2 was templated", File.read(method_path('two.txt'))
      was_in_block = true
    end
    
    assert_equal "<%= one %> was templated", File.read(method_path('one.txt'))
    assert_equal "<%= two %> was templated", File.read(method_path('two.txt'))
    assert was_in_block
  end
  
end



