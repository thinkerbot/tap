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
  # match test
  #
  
  def test_match_matches_constants_by_const_name
    env = Env.new :constants => [
      Constant.new('A'),
      Constant.new('A::B'),
      Constant.new('A::B::C'),
      Constant.new('C')
    ]
    
    assert_equal ['A'], env.match('A').map(&:const_name)
    assert_equal ['A'], env.match('::A').map(&:const_name)
    assert_equal ['C'], env.match('C').map(&:const_name)
    assert_equal ['A::B::C'], env.match('A::B::C').map(&:const_name)
    assert_equal ['A::B::C'], env.match('::A::B::C').map(&:const_name)
  end
  
  def test_match_matches_constants_by_path_matching
    env = Env.new :constants => [
      Constant.new('A'),
      Constant.new('A::B'),
      Constant.new('A::B::C'),
      Constant.new('C')
    ]
    
    assert_equal ['A'], env.match('a').map(&:const_name)
    assert_equal ['A'], env.match('/a').map(&:const_name)
    assert_equal ['A::B'], env.match('b').map(&:const_name)
    assert_equal ['A::B'], env.match('a/b').map(&:const_name)
    assert_equal ['A::B'], env.match('/a/b').map(&:const_name)
    assert_equal ['A::B::C'], env.match('a:c').map(&:const_name)
    assert_equal ['A::B::C'], env.match('/a/b/c:').map(&:const_name)
    assert_equal ['A::B::C'], env.match(':/a/b/c').map(&:const_name)
    assert_equal ['C'], env.match('c:').map(&:const_name)
    assert_equal ['C'], env.match('/c:').map(&:const_name)
    assert_equal ['A::B::C', 'C'], env.match('c').map(&:const_name)
  end
  
  def test_match_filters_by_type_if_specified
    env = Env.new :constants => [
      Constant.new('A').register_as('one'),
      Constant.new('B::A').register_as('two')
    ]
    
    assert_equal ['A'], env.match('a', 'one').map(&:const_name)
    assert_equal ['B::A'], env.match('a', 'two').map(&:const_name)
    assert_equal ['A', 'B::A'], env.match('a', ['one', 'two']).map(&:const_name)
  end
  
  def test_match_filters_by_inline_type_if_specified
    env = Env.new :constants => [
      Constant.new('A').register_as('one'),
      Constant.new('B::A').register_as('two')
    ]
    
    assert_equal ['A'], env.match('a::one').map(&:const_name)
    assert_equal ['B::A'], env.match('a::two').map(&:const_name)
    assert_equal ['B::A'], env.match('a::two', 'one').map(&:const_name)
  end
  
  def test_path_matching_only_matches_along_word_breaks
    env = Env.new :constants => [
      Constant.new('Nested::Const::Name')
    ]
    
    assert_equal [], env.match('ame')
    assert_equal [], env.match('/nest:')
  end
  
  def test_match_stringifies_inputs
    env = Env.new :constants => [
      Constant.new('A')
    ]
    
    assert_equal ['A'], env.match('a').map(&:const_name)
    assert_equal ['A'], env.match(:a).map(&:const_name)
  end
  
  #
  # constant test
  #
  
  def test_constant_returns_the_constant_matching_key
    env = Env.new :constants => [ConstName, Nest::ConstName]
    
    assert_equal ConstName, env.constant('/const_name')
    assert_equal Nest::ConstName, env.constant('/nest/const_name')
  end
  
  #
  # loadpath test
  #
  
  def test_loadpath_expands_and_prepends_paths_to_LOAD_PATH_ensuring_no_duplicates
    current = $LOAD_PATH.dup
    begin
      $LOAD_PATH.clear
      
      env = Env.new
      env.loadpath 'a', '/b', '/c'
      assert_equal [File.expand_path('a'), '/b', '/c'], $LOAD_PATH
      
      env.loadpath '/c', '/d'
      assert_equal ['/c', '/d', File.expand_path('a'), '/b'], $LOAD_PATH
      
    ensure
      $LOAD_PATH.clear
      $LOAD_PATH.concat current
    end
  end
end