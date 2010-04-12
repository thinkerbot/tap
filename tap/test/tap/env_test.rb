require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/env'

class EnvTest < Test::Unit::TestCase
  acts_as_file_test
  acts_as_shell_test
  Env = Tap::Env
  Path = Tap::Env::Path
  Constant = Tap::Env::Constant
  
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
    env = Env.new :constants => [ConstName]
    assert_equal 'ConstName', env.constants[0].const_name
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
  # resolve test
  #
  
  def test_resolve_resolves_constants_by_const_name
    env = Env.new :constants => [
      Constant.new('A'),
      Constant.new('A::B'),
      Constant.new('A::B::C'),
      Constant.new('C')
    ]
    
    assert_equal 'A', env.resolve('A').const_name
    assert_equal 'A', env.resolve('::A').const_name
    assert_equal 'C', env.resolve('C').const_name
    assert_equal 'A::B::C', env.resolve('A::B::C').const_name
    assert_equal 'A::B::C', env.resolve('::A::B::C').const_name
  end
  
  def test_resolve_resolves_constants_by_path_matching
    env = Env.new :constants => [
      Constant.new('A'),
      Constant.new('A::B'),
      Constant.new('A::B::C'),
      Constant.new('C')
    ]
    
    assert_equal 'A', env.resolve('a').const_name
    assert_equal 'A', env.resolve('/a').const_name
    assert_equal 'A::B', env.resolve('b').const_name
    assert_equal 'A::B', env.resolve('a/b').const_name
    assert_equal 'A::B', env.resolve('/a/b').const_name
    assert_equal 'A::B::C', env.resolve('a:c').const_name
    assert_equal 'A::B::C', env.resolve('/a/b/c:').const_name
    assert_equal 'A::B::C', env.resolve(':/a/b/c').const_name
    assert_equal 'C', env.resolve('c:').const_name
    assert_equal 'C', env.resolve('/c:').const_name
  end
  
  def test_path_matching_forces_match_along_word_breaks
    env = Env.new :constants => [
      Constant.new('Nested::Const::Name')
    ]
    
    assert_raises(RuntimeError) { env.resolve('ame') }
    assert_raises(RuntimeError) { env.resolve('/nest:') }
  end
  
  def test_resolve_stringifies_inputs
    env = Env.new :constants => [
      Constant.new('A')
    ]
    
    assert_equal 'A', env.resolve('a').const_name
    assert_equal 'A', env.resolve(:a).const_name
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