require File.expand_path('../../tap_test_helper', __FILE__)
require File.expand_path('../../fixtures/constants', __FILE__)

require 'tap/env'
require 'tap/test'

class EnvTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  acts_as_shell_test
  
  Env = Tap::Env
  Path = Tap::Env::Path
  
  #
  # initialize test
  #
  
  def test_initialize_casts_paths
    env = Env.new :paths => [
      method_root.path('a'), 
      [method_root.path('b'), {'key' => 'value'}]
    ]
    
    assert_equal [
      method_root.path('a'),
      method_root.path('b')
    ], env.paths.collect {|path| path.base }
    
    assert_equal [
      {},
      {'key' => [method_root.path('b/value')]}
    ], env.paths.collect {|path| path.map }
  end
  
  def test_initialize_casts_constants
    env = Env.new :constants => [
      ConstName, 
      ['Nest::ConstName', 'require/path/a:require/path/b']
    ]
    
    assert_equal [
      'ConstName',
      'Nest::ConstName'
    ], env.constants.values.collect {|const| const.const_name }.sort
    
    assert_equal [
      [],
      ['require/path/a', 'require/path/b']
    ], env.constants.values.collect {|const| const.require_paths }.sort
  end
  
  #
  # path test
  #
  
  def test_path_returns_collection_of_paths_for_type
    a = Path.new method_root.path('a'), {'key' => 'one'}
    b = Path.new method_root.path('b'), {'key' => 'two:three'}
    
    env = Env.new :paths => [a, b]
    
    assert_equal [
      method_root.path('a/one'),
      method_root.path('b/two'),
      method_root.path('b/three')
    ], env.path('key')
    
    assert_equal [
      method_root.path('a/alt'),
      method_root.path('b/alt')
    ], env.path('alt')
  end
  
  #
  # constant test
  #
  
  def test_constant_returns_the_constant_matching_key
    env = Env.new :constants => [ConstName, Nest::ConstName]
    
    assert_equal ConstName, env.constant('/const_name')
    assert_equal Nest::ConstName, env.constant('/nest/const_name')
  end
end