require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :c
  def setup
    @c = Configuration.new('name')
  end
  
  #
  # initialization test
  #
  
  def test_initialization
    c = Configuration.new('name')
    assert_equal 'name', c.name
    assert_equal nil, c.default
    assert_equal :mandatory, c.arg
    assert_equal :name, c.getter
    assert_equal :name=, c.setter
  end
  
  #
  # getter= test
  #

  def test_set_getter_symbolizes_input
    c.getter = 'getter'
    assert_equal :getter, c.getter
  end
  
  #
  # setter= test
  #

  def test_set_setter_symbolizes_input
    c.setter = 'setter='
    assert_equal :setter=, c.setter
  end  
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_all_attributes_are_equal
    config = Configuration.new('name')
    another = Configuration.new('name')
    assert config == another
    
    config = Configuration.new('name')
    another = Configuration.new('alt')
    assert config != another
    
    config = Configuration.new('name', 1)
    another = Configuration.new('name', 2)
    assert config != another
    
    config = Configuration.new('name', 1, :mandatory)
    another = Configuration.new('name', 1, :optional)
    assert config != another
    
    config = Configuration.new('name', 1, :mandatory, :getter)
    another = Configuration.new('name', 1, :optional, :alt)
    assert config != another
    
    config = Configuration.new('name', 1, :mandatory, :getter, :setter=)
    another = Configuration.new('name', 1, :optional, :getter, :alt=)
    assert config != another
  end
end
