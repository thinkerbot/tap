require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/versions'

class VersionTest < Test::Unit::TestCase
  include Tap::Support::Versions
  include Tap::Test::SubsetTest

  def test_documentation
    assert_equal "path/to/file-1.0.txt", version("path/to/file.txt", 1.0)  
    assert_equal "path/to/file-1.0.1.txt", increment("path/to/file-1.0.txt", "0.0.1")  
    assert_equal "path/to/file-1.0.txt", increment("path/to/file.txt", 1.0)  
    assert_equal ["path/to/file.txt", "1.0"], deversion("path/to/file-1.0.txt")  
    assert_equal ["path/to/file.txt", nil], deversion("path/to/file.txt")
  end

  #
  # version tests
  #
  
  def test_version_accepts_string_or_numeric_versions
    assert_equal "path/to/file-1.1.txt", version("path/to/file.txt", "1.1")
    assert_equal "path/to/file-1.1.txt", version("path/to/file.txt", 1.1)
    
    assert_equal "path/to/file-1.1", version("path/to/file", "1.1")
  end
  
  def test_version_defaults_to_filepath_when_no_version_is_specified
    assert_equal "path/to/file.txt", version("path/to/file.txt", "")
    assert_equal "path/to/file.txt", version("path/to/file.txt", "  ")
    assert_equal "path/to/file.txt", version("path/to/file.txt", nil)
    
    assert_equal "path/to/file", version("path/to/file", "")
  end
  
  #
  # deversion tests
  #

  def test_deversion_returns_filepath_and_version
    assert_equal ["path/to/file.txt", "1.1"], deversion("path/to/file-1.1.txt")
    assert_equal ["path/to/file", "1.1"], deversion("path/to/file-1.1")
    assert_equal ["path/to/file.txt", "1"], deversion("path/to/file-1.txt")
    assert_equal ["path/to/file.txt", "12.34.56"], deversion("path/to/file-12.34.56.txt")
    assert_equal ["path/to-0.1/file.txt", "1.0"], deversion("path/to-0.1/file-1.0.txt")
  end
  
  def test_deversion_returns_nil_for_version_when_no_version_is_specified
    assert_equal ["path/to/file.txt", nil], deversion("path/to/file.txt")
    assert_equal ["path/to/file", nil], deversion("path/to/file")
    assert_equal ["path/to-0.1/file", nil], deversion("path/to-0.1/file")
  end
  
  #
  # increment tests
  #

  def test_increment_adds_increment_to_current_version
    assert_equal "path/to/file-1.0.1.txt", increment("path/to/file-1.0.txt", "0.0.1")
    assert_equal "path/to/file-2.1.txt", increment("path/to/file-1.0.txt", 1.1)
    assert_equal "path/to/file-2.0.txt", increment("path/to/file-1.0.txt", 1)
    assert_equal "path/to/file-1.1.txt", increment("path/to/file.txt", 1.1)
    
    assert_equal "path/to/file-1.0.1", increment("path/to/file-1.0", "0.0.1")
    assert_equal "path/to/file-2.1", increment("path/to/file-1.0", 1.1)
    assert_equal "path/to/file-2.0", increment("path/to/file-1.0", 1)
    assert_equal "path/to/file-1.1", increment("path/to/file", 1.1)
  end
  
  def test_increment_adds_zero_if_increment_is_nil
    assert_equal "path/to/file-1.0.txt", increment("path/to/file-1.0.txt", nil)
    assert_equal "path/to/file.txt", increment("path/to/file.txt", nil)
    
    assert_equal "path/to/file-1.0", increment("path/to/file-1.0", nil)
    assert_equal "path/to/file", increment("path/to/file", nil)
  end
  
  #
  # compare versions test
  #
  
  def test_compare_versions_documentation
    assert_equal 1, compare_versions("1.0.0", "0.9.9")             
    assert_equal 0, compare_versions(1.1, 1.1)                             
    assert_equal(-1,  compare_versions([0,9], [0,9,1]) )                 
  end
  
  def test_compare_versions
    [
      ["1", "0"], 
      ["1.1", "1.0"],
      ["1.0", "0.9"], 
      ["1.0.0.0", "0.9"], 
      ["1.0", "0.9.0.0"]
    ].each do |a,b|
      assert_equal 1, compare_versions(a,b)
      assert_equal 0, compare_versions(a,a)
      assert_equal 0, compare_versions(b,b)
      assert_equal(-1, compare_versions(b,a))
    end
  end

  def test_compare_versions_handles_numeric_and_array_input
    assert_equal 1, compare_versions(1, 0.9)
    assert_equal 1, compare_versions([1,0], [0,9])
    assert_equal 1, compare_versions(["1","0"], ["0","9"])
  end
  
  #
  # vniq test
  #
  
  def test_vniq_documentation
    paths = [
     "/path/to/two-0.0.1.txt",
     "/path/to/one-0.0.1.txt",
     "/path/to/one.txt",
     "/path/to/two-1.0.1.txt",
     "/path/to/three.txt"]
     
    expected = [
    "/path/to/one-0.0.1.txt",
    "/path/to/two-1.0.1.txt",
    "/path/to/three.txt"]
    
    assert_equal expected, vniq(paths)
  end
  
  def test_vniq_returns_array_of_latest_paths
    paths = [
      "/path/to/one-0.0.1.txt",
      "/path/to/one-1.0.1.txt",
      "/path/to/one-1.txt",
      "/path/to/two-0.0.1.txt",
      "/path/to/three-1.txt",
      "/path/to/four.txt",
      "/path/to/five-0.1.2.txt",
      "/path/to/five-0.2.1.txt"
    ]
    
    expected = [
      "/path/to/one-1.0.1.txt",
      "/path/to/two-0.0.1.txt",
      "/path/to/three-1.txt",
      "/path/to/four.txt",
      "/path/to/five-0.2.1.txt"
    ]
    
    assert_equal expected, vniq(paths)
  end
  
  def test_vniq_returns_array_of_earliest_paths_if_specified
    paths = [
      "/path/to/one-0.0.1.txt",
      "/path/to/one-1.0.1.txt",
      "/path/to/one-1.txt",
      "/path/to/two-0.0.1.txt",
      "/path/to/three-1.txt",
      "/path/to/four.txt",
      "/path/to/five-0.1.2.txt",
      "/path/to/five-0.2.1.txt"
    ]
    
    expected = [
      "/path/to/one-0.0.1.txt",
      "/path/to/two-0.0.1.txt",
      "/path/to/three-1.txt",
      "/path/to/four.txt",
      "/path/to/five-0.1.2.txt"
    ]
    
    assert_equal expected, vniq(paths, true)
  end
  
  def test_vniq_considers_any_version_beats_no_version
    paths = [
      "/path/to/two.txt",
      "/path/to/one-0.0.1.txt",
      "/path/to/one.txt",
      "/path/to/two-1.0.1.txt"
    ]
    
    expected = [
      "/path/to/one-0.0.1.txt",
      "/path/to/two-1.0.1.txt"
    ]
    
    assert_equal expected, vniq(paths)
  end
  
end