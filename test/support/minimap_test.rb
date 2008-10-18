require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/minimap'
require 'tap/support/string_ext'

class MinimapTest < Test::Unit::TestCase
  include Tap::Support
  
  class ConstantMap < Array
    include Tap::Support::Minimap

    def minikey(const)
      const.to_s.underscore
    end
  end
  
  def test_minimap_documentation
    paths = %w{
      path/to/file-0.1.0.txt 
      path/to/file-0.2.0.txt
      path/to/another_file.txt
    }
    paths.extend Minimap
  
    assert_equal 'path/to/file-0.1.0.txt', paths.minimatch('file')
    assert_equal 'path/to/file-0.2.0.txt', paths.minimatch('file-0.2.0')
    assert_equal 'path/to/another_file.txt', paths.minimatch('another_file')
  
    constants = ConstantMap[Tap::Support::Minimap, Tap::Root]
    assert_equal Tap::Root, constants.minimatch('root')
    assert_equal Tap::Support::Minimap, constants.minimatch('minimap')
  end
  
  #
  # minimap test
  #
  
  def test_minimap_documentation
    paths = %w{
      path/to/file-0.1.0.txt 
      path/to/file-0.2.0.txt
      path/to/another_file.txt
    }.extend Minimap
  
    expected = [
    ['file-0.1.0',  'path/to/file-0.1.0.txt'],
    ['file-0.2.0',  'path/to/file-0.2.0.txt'],
    ['another_file','path/to/another_file.txt']]
    
    assert_equal expected, paths.minimap
  end
  
  #
  # minimatch test
  #
  
  def test_minimatch_documentation
    paths = %w{
      path/to/file-0.1.0.txt 
      path/to/file-0.2.0.txt
      path/to/another_file.txt
    }.extend Minimap
  
    assert_equal 'path/to/file-0.2.0.txt', paths.minimatch('file-0.2.0')
    assert_equal nil, paths.minimatch('file-0.3.0')
  end
end