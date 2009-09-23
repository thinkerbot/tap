require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/constant'

# used in tests
module ConstName
end

module ConstantNest
  module ConstName
  end
end

module UnloadNest
  module UnloadName
  end
end

class ConstantTest < Test::Unit::TestCase
  Constant = Tap::Env::Constant
  
  attr_accessor :c, :nested
  
  def setup
    @c = Constant.new('ConstName')
    @nested = Constant.new('Nested::Sample::ConstName')
  end
  
  #
  # documentation test
  #
  
  def test_documentation
    assert_equal false, Object.const_defined?(:Net)
    assert_equal false, $".include?('net/http.rb')
  
    http = Constant.new('Net::HTTP', 'net/http.rb')
    assert_equal http.constantize, Net::HTTP
    assert_equal true, $".include?('net/http.rb')
  
    # [simple.rb]
    # class Simple
    # end
    
    load_path = File.expand_path("#{File.dirname(__FILE__)}/constant")
    begin
      assert !$:.include?(load_path)
      $: << load_path
    
      const = Constant.new('Simple', 'simple')
      assert_equal const.constantize, Simple
      assert_equal true, Object.const_defined?(:Simple)
  
      assert_equal Simple, const.unload
      assert_equal false, Object.const_defined?(:Simple)
  
      assert_equal const.constantize, Simple
      assert_equal true, Object.const_defined?(:Simple)
    ensure
      $:.delete(load_path)
    end
  end
  
  #
  # constantize test
  #
  
  def test_constantize_documentation
    assert_equal ConstName, Constant.constantize('ConstName')
    assert_equal(ConstName, Constant.constantize('Non::Existant') { ConstName })
  end
  
  def test_constantize_returns_the_existing_constant
    # ::ConstName
    assert_equal ConstName, Constant.constantize("ConstName")
    assert_equal ConstName, Constant.constantize("::ConstName")
    assert_equal ConstName, Constant.constantize("Object::ConstName")
    
    # ConstantNest::ConstName
    assert_equal ConstantNest::ConstName, Constant.constantize("ConstantNest::ConstName")
    assert_equal ConstantNest::ConstName, Constant.constantize("::ConstantNest::ConstName")
    assert_equal ConstantNest::ConstName, Constant.constantize("Object::ConstantNest::ConstName")
  end
  
  def test_constantize_starts_looking_for_the_constant_under_const
    assert_equal ConstantNest::ConstName, Constant.constantize("ConstName", ConstantNest)
    assert_equal ConstantNest::ConstName, Constant.constantize("::ConstName", ConstantNest)
  end
  
  def test_constantize_raise_error_for_invalid_constant_names
    assert_raises(NameError) { Constant.constantize("") }
    assert_raises(NameError) { Constant.constantize("::") }
    assert_raises(NameError) { Constant.constantize("const_name") }
  end
  
  def test_constantize_raises_error_if_constant_does_not_exist
    assert_raises(NameError) { Constant.constantize("Non::Existant") }
    assert_raises(NameError) { Constant.constantize("::Non::Existant") }
    assert_raises(NameError) { Constant.constantize("ConstName", ConstName) }
    assert_raises(NameError) { Constant.constantize("::ConstName", ConstName) }
    assert_raises(NameError) { Constant.constantize("Object::ConstName", ConstName) }
  end
  
  def test_constantize_yields_current_const_and_missing_constant_names_to_the_block
    was_in_block = false
    Constant.constantize("Non::Existant") do |const, const_names|
      assert_equal Object, const
      assert_equal ["Non", "Existant"], const_names
      was_in_block = true
    end
    assert was_in_block
    
    was_in_block = false
    Constant.constantize("ConstName::Non::Existant") do |const, const_names|
      assert_equal ConstName, const
      assert_equal ["Non", "Existant"], const_names
      was_in_block = true
    end
    assert was_in_block
  end
  
  def test_constantize_returns_return_value_of_block_when_yielding_to_the_block
    assert_equal(ConstName, Constant.constantize("ConstName") { false })
    assert_equal(false, Constant.constantize("Non::Existant") { false })
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Constant.new('ConstName')
    assert_equal 'ConstName', c.const_name
    assert_equal [], c.require_paths
    
    c = Constant.new('Sample::Const', '/path/to/sample/const.rb')
    assert_equal 'Sample::Const', c.const_name
    assert_equal ['/path/to/sample/const.rb'], c.require_paths
  end
  
  #
  # path test
  #
  
  def test_path_documentation
    assert_equal "const/name", Constant.new("Const::Name").path
  end
  
  def test_path_returns_underscored_const_name
    assert_equal 'const_name', c.path
    assert_equal 'nested/sample/const_name', nested.path
  end
  
  #
  # basename test
  #
  
  def test_basename_documentation
    assert_equal "name", Constant.new("Const::Name").basename
  end
  
  def test_basename_returns_the_basename_of_path
    assert_equal 'const_name', c.basename
    assert_equal 'const_name', nested.basename
  end
  
  #
  # dirname test
  #
  
  def test_dirname_documentation
    assert_equal "const", Constant.new("Const::Name").dirname
  end
  
  def test_dirname_returns_the_path_minus_basename
    assert_equal '', c.dirname
    assert_equal 'nested/sample', nested.dirname
  end
  
  #
  # name test
  #
  
  def test_name_documentation
    assert_equal "Name", Constant.new("Const::Name").name
  end
  
  def test_name_returns_const_name_minus_nesting
    assert_equal 'ConstName', c.name
    assert_equal 'ConstName', nested.name
  end
  
  #
  # nesting test
  #
  
  def test_nesting_documentation
    assert_equal "Const", Constant.new("Const::Name").nesting
  end
  
  def test_nesting_returns_the_nesting_for_const_name
    assert_equal '', c.nesting
    assert_equal 'Nested::Sample', nested.nesting
  end
  
  #
  # nesting_depth test
  #
  
  def test_nesting_depth_documentation
    assert_equal 1, Constant.new("Const::Name").nesting_depth
  end
  
  # 
  # == test
  #
  
  def test_constants_are_equal_if_const_name_and_require_paths_are_equal
    c1 = Constant.new('Sample::Const', '/require/path.rb')
    c2 = Constant.new('Sample::Const', '/require/path.rb')
    
    c3 = Constant.new('Another::Const', '/require/path.rb')
    c4 = Constant.new('Sample::Const', '/another/path.rb')
    
    assert c1.object_id != c2.object_id
    assert_equal c1, c2
    
    assert c1 == c2
    assert c2 == c1
    assert c1 != c3
    assert c1 != c4
  end
  
  #
  # register_as test
  #
  
  def test_register_as_adds_the_type_and_summary_to_types
    c = Constant.new('ConstName')
    assert_equal({}, c.types)
    
    c.register_as(:type, "summary")
    assert_equal({:type => "summary"}, c.types)
  end
  
  def test_register_as_raises_an_error_if_already_registered_to_the_type
    c = Constant.new('ConstName')
    c.types[:type] = "summary"
    
    err = assert_raises(RuntimeError) { c.register_as(:type, "override summary") }
    assert_equal "already registered as a :type", err.message
    assert_equal({:type => "summary"}, c.types)
  end
  
  def test_register_as_overrides_if_specified
    c = Constant.new('ConstName')
    c.types[:type] = "summary"
    
    c.register_as(:type, "override summary", true)
    assert_equal({:type => "override summary"}, c.types)
  end
  
  #
  # constantize test
  #
  
  def test_constantize_returns_the_constant_corresponding_to_const_name
    assert_equal Object, Constant.new('Object').constantize
    assert_equal Tap, Constant.new('Tap').constantize
    assert_equal Constant, Constant.new('Tap::Env::Constant').constantize
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
    
    assert_raises(NameError) { Constant.new('TotallyUnknownConstant').constantize }
    assert_raises(NameError) { Constant.new('TotallyUnknownConstant', empty_file).constantize }
  end
  
  #
  # unload test
  #
  
  def test_unload_undefines_const_and_removes_require_path_from_const
    require_path = File.expand_path("#{File.dirname(__FILE__)}/constant/unload_path.rb")
    require require_path
    
    assert Object.const_defined?(:UnloadPath)
    assert $".include?(require_path)
    
    unload_const = Object.const_get(:UnloadPath)
    const = Constant.new('UnloadPath', require_path)
    assert_equal unload_const, const.unload
    
    assert !Object.const_defined?(:UnloadPath)
    assert !$".include?(require_path)
  end
  
  def test_unload_does_not_undefine_nesting
    unload_const = UnloadNest::UnloadName
    const = Constant.new('UnloadNest::UnloadName')
    assert_equal unload_const, const.unload
    
    assert Object.const_defined?(:UnloadNest)
    assert !UnloadNest.const_defined?(:UnloadName)
  end
  
  def test_unload_does_nothing_if_constant_is_not_defined
    empty_file = "#{File.dirname(__FILE__)}/constant/empty_file.rb"
    require empty_file
    assert !Object.const_defined?(:TotallyUnknownConstant)
    assert $".include?(empty_file)
    
    const = Constant.new('TotallyUnknownConstant', empty_file)
    assert_equal nil, const.unload
    assert $".include?(empty_file)
    
    const = Constant.new('TotallyUnknownConstant::NestedConstant', empty_file)
    assert_equal nil, const.unload
    assert $".include?(empty_file)
  end
  
  #
  # inspect test
  #
  
  def test_inspect
    c = Constant.new('Sample::Const')
    assert_equal "#<Tap::Env::Constant:#{c.object_id} Sample::Const []>", c.inspect
    
    c = Constant.new('Sample::Const', '/require/path.rb')
    assert_equal "#<Tap::Env::Constant:#{c.object_id} Sample::Const [\"/require/path.rb\"]>", c.inspect
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_const_name
    assert_equal 'Sample::Const', Constant.new('Sample::Const').to_s
  end
end