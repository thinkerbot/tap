require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/minimap'
require 'tap/root/string_ext'

class MinimapTest < Test::Unit::TestCase
  Minimap = Tap::Env::Minimap
  
  class ConstantMap < Array
    include Tap::Env::Minimap

    def entry_to_minikey(const)
      const.to_s.underscore
    end
  end
  
  def test_documentation
    paths = %w{
      path/to/file-0.1.0.txt 
      path/to/file-0.2.0.txt
      path/to/another_file.txt
    }
    paths.extend Minimap
  
    assert_equal 'path/to/file-0.1.0.txt', paths.minimatch('file')
    assert_equal 'path/to/file-0.2.0.txt', paths.minimatch('file-0.2.0')
    assert_equal 'path/to/another_file.txt', paths.minimatch('another_file')
  
    constants = ConstantMap[Tap::Env::Minimap, Tap::Env]
    assert_equal Tap::Env, constants.minimatch('env')
    assert_equal Tap::Env::Minimap, constants.minimatch('minimap')
  end
  
  #
  # api test
  #
  
  def test_minimap_exposes_only_public_methods
    paths = Object.new.extend Minimap
    
    assert paths.respond_to?(:minimap)
    assert !paths.respond_to?(:minimize)
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
  
  #
  # Minimap.Minimap.minimize test
  #
  
  def test_minimize_documentation
    assert_equal ['a', 'b'], Minimap.minimize(['path/to/a.rb', 'path/to/b.rb'])
    assert_equal ['a', 'b'], Minimap.minimize(['path/to/a-0.1.0.rb', 'path/to/b-0.1.0.rb'])
    assert_equal ['file.rb', 'file.txt'], Minimap.minimize(['path/to/file.rb', 'path/to/file.txt'])
    assert_equal ['path-0.1/to/file', 'path-0.2/to/file'], Minimap.minimize(['path-0.1/to/file.rb', 'path-0.2/to/file.rb'])
    assert_equal ['a-0.1.0.rb', 'a-0.1.0.txt'], Minimap.minimize(['path/to/a-0.1.0.rb', 'path/to/a-0.1.0.txt'])
    assert_equal ['a-0.1.0', 'a-0.2.0'], Minimap.minimize(['path/to/a-0.1.0.rb', 'path/to/a-0.2.0.rb'])
  end
  
  def test_minimize_collects_unique_basenames_for_paths
    # some extreme cases
    assert_equal [], Minimap.minimize([])
    assert_equal ['a'], Minimap.minimize(['a.txt'])
    assert_equal ['a'], Minimap.minimize(['a.txt', 'a.txt'])
    
    # cases where extname and version is dropped
    assert_equal ['c', 'C'], Minimap.minimize(['a/b/c.txt', 'a/b/C.txt'])  
    assert_equal ['c', 'C'], Minimap.minimize(['a/b/c.txt', 'a/b/C.rb'])  
    assert_equal ['c', 'C'], Minimap.minimize(['a/b/c-0.1.txt', 'a/b/C-0.1.txt'])  
    assert_equal ['c', 'C'], Minimap.minimize(['a/b/c-0.1.txt', 'a/b/C-0.2.txt']) 
    
    assert_equal ['b/c', 'B/c'], Minimap.minimize(['a/b/c.txt', 'a/B/c.txt'])  
    assert_equal ['b/c', 'B/c'], Minimap.minimize(['a/b/c.txt', 'a/B/c.rb'])  
    assert_equal ['b/c', 'B/c'], Minimap.minimize(['a/b/c-0.1.txt', 'a/B/c-0.1.txt'])  
    assert_equal ['b/c', 'B/c'], Minimap.minimize(['a/b/c-0.1.txt', 'a/B/c-0.2.txt'])
    
    assert_equal ['a/b/c', 'A/b/c'], Minimap.minimize(['a/b/c.txt', 'A/b/c.txt'])  
    assert_equal ['a/b/c', 'A/b/c'], Minimap.minimize(['a/b/c.txt', 'A/b/c.rb'])  
    assert_equal ['a/b/c', 'A/b/c'], Minimap.minimize(['a/b/c-0.1.txt', 'A/b/c-0.1.txt'])  
    assert_equal ['a/b/c', 'A/b/c'], Minimap.minimize(['a/b/c-0.1.txt', 'A/b/c-0.2.txt'])
    
    assert_equal ['b-0.1/c', 'b-0.2/c'], Minimap.minimize(['a/b-0.1/c.txt', 'a/b-0.2/c.txt'])  
    assert_equal ['a/b-0.1/c', 'A/b-0.1/c'], Minimap.minimize(['a/b-0.1/c.txt', 'A/b-0.1/c.rb'])  
    assert_equal ['b-0.1/c', 'b-0.2/c'], Minimap.minimize(['a/b-0.1/c-0.1.txt', 'a/b-0.2/c-0.1.txt'])  
    assert_equal ['a/b-0.1/c', 'A/b-0.1/c'], Minimap.minimize(['a/b-0.1/c-0.1.txt', 'A/b-0.1/c-0.2.txt'])
    
    # cases where version is kept
    assert_equal ['c-0.1', 'c-0.2'], Minimap.minimize(['a/b/c-0.1.txt', 'a/b/c-0.2.txt'])  
    assert_equal ['c-0.1', 'c-0.2'], Minimap.minimize(['a/b/c-0.1.txt', 'a/b/c-0.2.rb'])  
    assert_equal ['c-0.1', 'c-0.2'], Minimap.minimize(['a/b/c-0.1', 'a/b/c-0.2'])  
    assert_equal ['c-0.1', 'c-0.2'], Minimap.minimize(['a/b/c-0.1', 'a/b/c-0.2'])
    
    # cases where ext is kept
    assert_equal ['c.txt', 'c.rb'], Minimap.minimize(['a/b/c.txt', 'a/b/c.rb'])  
    assert_equal ['c-0.1.txt', 'c-0.1.rb'], Minimap.minimize(['a/b/c-0.1.txt', 'a/b/c-0.1.rb'])

    # a complex case
    paths = %w{
      a/b/c.d
      a/b/c.d
      a/b/C.d
      a/b/c.D
      a/B/c.d
      A/b/c.d
      
      a/b-0.1/c.d
      a/b-0.2/c.d
      a/b/c-0.1.d
      a/b/c-0.2.d
    }
    
    expected = %w{
      c.d
      c.D
      C
      B/c
      A/b/c
      b-0.1/c
      b-0.2/c
      c-0.1
      c-0.2
    }
    
    assert_equal expected.sort, Minimap.minimize(paths).sort
    
    # special cases where order is important so that all paths
    # can be identified.  (if the order were ['b/c', 'c', 'a/b/c'],  
    # then no linear minimal_match lookup could select c)
    assert_equal ['c', 'b/c', 'a/b/c'], Minimap.minimize(['b/c', 'a/b/c', 'c'])  
    assert_equal ['c', 'b/c', 'a/b/c'], Minimap.minimize(['b/c', 'c', 'a/b/c']) 
    assert_equal ['c', 'b/c', 'a/b/c'], Minimap.minimize(['c', 'a/b/c', 'b/c'])
    assert_equal ['c', 'b/c', 'a/b/c'], Minimap.minimize(['a/b/c', 'c', 'b/c'])  
     
    # note in these cases the order of '/b/c' and '/a/b/c' can be reversed
    # safely, because each Minimap.minimized paths still can be identified in order
    # ('a/b/c' and '/b/c'do not conflict)
    assert_equal ['/c', '/b/c', 'a/b/c'], Minimap.minimize(['/b/c', '/a/b/c', '/c'])  
    assert_equal ['/c', '/b/c', 'a/b/c'], Minimap.minimize(['/b/c', '/c', '/a/b/c']) 
    assert_equal ['/c', 'a/b/c', '/b/c'], Minimap.minimize(['/c', '/a/b/c', '/b/c'])
    assert_equal ['/c', 'a/b/c', '/b/c'], Minimap.minimize(['/a/b/c', '/c', '/b/c'])  
  end
  
  #
  # Minimap.minimal_match? test
  #
  
  def test_minimal_match_documentation
    assert Minimap.minimal_match?('dir/file-0.1.0.rb', 'file')
    assert Minimap.minimal_match?('dir/file-0.1.0.rb', 'dir/file')
    assert Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0')
    assert Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0.rb') 
  
    assert !Minimap.minimal_match?('dir/file-0.1.0.rb', 'file.rb')
    assert !Minimap.minimal_match?('dir/file-0.1.0.rb', 'file-0.2.0') 
    assert !Minimap.minimal_match?('dir/file-0.1.0.rb', 'another')
  
    assert Minimap.minimal_match?('dir/file-0.1.0.txt', 'file')
    assert !Minimap.minimal_match?('dir/file-0.1.0.txt', 'ile') 
    assert Minimap.minimal_match?('dir/file-0.1.0.txt', 'r/file')     
  end
  
  def test_minimal_match
    assert Minimap.minimal_match?('a/b/c.d', 'c')
    assert Minimap.minimal_match?('a/b/c.d', 'b/c')
    assert Minimap.minimal_match?('a/b/c.d', 'a/b/c')
    assert Minimap.minimal_match?('a/b/c.d', 'c.d')
    assert Minimap.minimal_match?('a/b/c.d', 'b/c.d')
    assert Minimap.minimal_match?('a/b/c.d', 'a/b/c.d')
    
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'c')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'b/c')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'a/b/c')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'c-0.1')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'b/c-0.1')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'a/b/c-0.1')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'c-0.1.d')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'b/c-0.1.d')
    assert Minimap.minimal_match?('a/b/c-0.1.d', 'a/b/c-0.1.d')
    
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'c')
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'b/c')
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'a/b/c')
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'c-0.0.1')
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'b/c-0.0.1')
    assert Minimap.minimal_match?('a/b/c-0.0.1', 'a/b/c-0.0.1')
    
    assert !Minimap.minimal_match?('a/b/c.d', 'C')
    assert !Minimap.minimal_match?('a/b/c.d', 'B/c')
    assert !Minimap.minimal_match?('a/b/c.d', 'A/b/c')
    assert !Minimap.minimal_match?('a/b/c.d', 'c.D')
    assert !Minimap.minimal_match?('a/b/c-0.1.d', 'c-0.2')
    assert !Minimap.minimal_match?('a/b/c-0.1.d', 'c.d')
  end
  
end