require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/constant'

class ConstantTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :c, :nested
  
  def setup
    @c = Constant.new('ConstName')
    @nested = Constant.new('Nested::Sample::ConstName')
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Constant.new('ConstName')
    assert_equal 'ConstName', c.name
    assert_equal nil, c.require_path
    
    c = Constant.new('Sample::Const', '/path/to/sample/const.rb')
    assert_equal 'Sample::Const', c.name
    assert_equal '/path/to/sample/const.rb', c.require_path
  end
  
  #
  # path test
  #
  
  def test_path_returns_underscored_name
    assert_equal 'const_name', c.path
    assert_equal 'nested/sample/const_name', nested.path
  end
  
  #
  # basename test
  #
  
  def test_basename_returns_the_basename_of_path
    assert_equal 'const_name', c.basename
    assert_equal 'const_name', nested.basename
  end
  
  #
  # dirname test
  #
  
  def test_dirname_returns_the_path_minus_basename
    assert_equal '', c.dirname
    assert_equal 'nested/sample', nested.dirname
  end
  
  #
  # const_name test
  #
  
  def test_const_name_returns_name_minus_nesting
    assert_equal 'ConstName', c.const_name
    assert_equal 'ConstName', nested.const_name
  end
  
  #
  # nesting test
  #
  
  def test_nesting_returns_the_nesting_for_name
    assert_equal '', c.nesting
    assert_equal 'Nested::Sample', nested.nesting
  end
  
  #
  # document test
  #
  
  def test_document_returns_document_for_require_path
    c = Constant.new('Sample::Const', '/path/to/sample/const_test_file.rb')
    assert_equal Lazydoc['/path/to/sample/const_test_file.rb'], c.document
  end
  
  def test_document_returns_nil_if_require_path_is_not_set
    assert_equal nil, c.require_path
    assert_equal nil, c.document
  end
  
  # 
  # == test
  #
  
  def test_constants_are_equal_if_name_and_require_path_are_equal
    c1 = Constant.new('Sample::Const', '/require/path.rb')
    c2 = Constant.new('Sample::Const', '/require/path.rb')
    c3 = Constant.new('Another::Const', '/require/path.rb')
    c4 = Constant.new('Sample::Const', '/another/path.rb')
    
    assert_not_equal c1.object_id, c2.object_id
    assert_equal c1, c2
    
    assert c1 == c2
    assert c2 == c1
    assert c1 != c3
    assert c1 != c4
  end
  
  #
  # constantize test
  #
  
  def test_constantize_returns_the_constant_corresponding_to_name
    assert_equal Object, Constant.new('Object').constantize
    assert_equal Tap, Constant.new('Tap').constantize
    assert_equal Constant, Constant.new('Tap::Support::Constant').constantize
  end
  
  def test_constantize_requires_require_path_if_the_constant_cannot_be_found
    require_path = File.expand_path("#{File.dirname(__FILE__)}/constant/require_path.rb")
    
    assert !Object.const_defined?(:UnknownConstant)
    assert File.exists?(require_path)
    assert !$".include?(require_path)
    
    # assertion can't be done in on line since UnknownConstant
    # is not defined until after constantize
    const = Constant.new('UnknownConstant', require_path).constantize
    assert_equal UnknownConstant, const
    
    assert $".include?(require_path)
  end
  
  def test_constantize_raises_error_if_the_constant_cannot_be_found
    empty_file = "#{File.dirname(__FILE__)}/constant/empty_file.rb"
    assert !Object.const_defined?(:TotallyUnknownConstant)
    
    assert_raise(NameError) { Constant.new('TotallyUnknownConstant').constantize }
    assert_raise(NameError) { Constant.new('TotallyUnknownConstant', empty_file).constantize }
  end
  
  #
  # inspect test
  #
  
  def test_inspect
    c = Constant.new('Sample::Const')
    assert_equal "#<Tap::Support::Constant:#{c.object_id} Sample::Const>", c.inspect
    
    c = Constant.new('Sample::Const', '/require/path.rb')
    assert_equal "#<Tap::Support::Constant:#{c.object_id} Sample::Const (/require/path.rb)>", c.inspect
  end
end