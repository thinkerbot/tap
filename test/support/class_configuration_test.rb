require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/class_configuration'
require 'tap/support/validation'
require 'tap/support/configurable_methods'
require 'tap/support/tdoc'
require 'tap/support/configurable'

# for documentation test
class BaseTask 
  include Tap::Support::Configurable
  config :one, 1
end
class SubTask < BaseTask
  config :one, 'one'
  config :two, 'two'
end
class MergeTask < BaseTask
  config :three, 'three'
  config_merge SubTask
end
class ValidationTask < Tap::Task
  config :one, 'one', &c.check(String)
  config :two, 'two', &c.yaml(/two/, Integer)
  config :three, 'three' do |v| 
    v =~ /three/ ? v.upcase : raise("not three")
  end
end

class ClassConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  
  def test_config_merge
    t = MergeTask.new
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.config)
    assert t.respond_to?(:two)
    yaml = MergeTask.configurations.format_yaml
    expected = %Q{
# BaseTask configuration
one: one

# MergeTask configuration
three: three

# SubTask configuration
two: two
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 'one', 'two' => 'two', 'three' => 'three'}, YAML.load(yaml))
  end
  
  def test_config_validations
    t = ValidationTask.new
    assert_equal({:one => 'one', :two => 'two', :three => 'THREE'}, t.config)
    
    t.one = 'two'
    assert_equal 'two', t.one  
    assert_raise(Validation::ValidationError) { t.one = 1 }
    
    t.two = "two"
    assert_equal 'two', t.two
    t.two = 2
    assert_equal 2, t.two    
    t.two = "2"
    assert_equal 2, t.two
    assert_raise(Validation::ValidationError) { t.two = 'three' }
    assert_raise(Validation::ValidationError) { t.two = 2.2 }
    
    t.three = "three"
    assert_equal 'THREE', t.three
    assert_raise(RuntimeError) { t.three = 'THREE' } 
  end
  
  def test_initialization
    c = ClassConfiguration.new ClassConfigurationTest
    
    assert_equal ClassConfigurationTest, c.receiver
    assert_equal [], c.declarations
    assert_equal [[c.receiver, []]], c.declarations_array
    assert_equal({}, c.default)
    assert_equal({}, c.unprocessed_default)
    assert_equal({}, c.process_blocks)
  end

  #
  # format_yaml tests
  #
  
  def test_format_yaml_with_single_class
    cc = ClassConfiguration.new ClassConfigurationTest
    cc.add('one', 1)
    
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
one: 1
}
    
    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 1}, YAML.load(yaml))
  end

  def test_format_stringifies_keys
    cc = ClassConfiguration.new ClassConfigurationTest
    cc.add(:one, 1)
    
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
one: 1
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 1}, YAML.load(yaml))
  end
end 
class Hold
  def test_format_yaml_with_desc
    cc = ClassConfiguration.new
    cc.declare('one', ClassConfigurationTest)
    cc.set('one', 1, :desc => "comment")
    
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
one: 1               # comment
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 1}, YAML.load(yaml))
  end

  def test_format_yaml_with_long_desc
    cc = ClassConfiguration.new
    cc.declare('one', ClassConfigurationTest)
    cc.set('one', 1, :desc => 'comment longer than some twenty chars')

    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
# comment longer than some twenty chars
one: 1
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 1}, YAML.load(yaml))
  end

  def test_format_yaml_with_long_value
    cc = ClassConfiguration.new(['one', 'value longer than some twenty chars', 'comment', ClassConfigurationTest])
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
# comment
one: value longer than some twenty chars
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 'value longer than some twenty chars'}, YAML.load(yaml))
  end
  
#   def test_format_yaml_with_nil_value
#     cc = ClassConfiguration.new(['one', nil, 'comment', ClassConfigurationTest])
#     yaml = cc.format_yaml
#     expected = %Q{
# # ClassConfigurationTest configuration
# #one:                # comment
# }
# 
#     assert_equal expected[1..-1], yaml
#     assert_equal(false, YAML.load(yaml))
#   end
  
  def test_format_yaml_with_multiline_comment
    cc = ClassConfiguration.new(['one', 1, "multiline\ncomment", ClassConfigurationTest])
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
# multiline
# comment
one: 1
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 1}, YAML.load(yaml))
  end
  
  def test_format_yaml_with_multiline_value
    cc = ClassConfiguration.new(['one', [1,2,3], "comment", ClassConfigurationTest])
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
# comment
one: 
- 1
- 2
- 3
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => [1,2,3]}, YAML.load(yaml))
  end
  
  def test_format_yaml_with_multiple_classes
    cc = ClassConfiguration.new(
      ['one', 1, '', ClassConfigurationTest],
      ['one', 'one', 'integer', AnotherClass],
      ['two', {'key' => 'value'}, 'hash', AnotherClass],
      ['three', [1,2,3], "multiline\narray", AnotherClass])
    yaml = cc.format_yaml
    expected = %Q{
# ClassConfigurationTest configuration
one: one             # integer

# ClassConfigurationTest::AnotherClass configurations
# hash
two: 
  key: value
# multiline
# array
three: 
- 1
- 2
- 3
}

    assert_equal expected[1..-1], yaml
    assert_equal({'one' => 'one', 'two' => {'key' => 'value'}, 'three' => [1,2,3]}, YAML.load(yaml))
  end
end

class Hold
  
#   def test_documentation
#     assert_equal({:one => 1}, BaseTask.configurations.hash)
#     assert_equal({:one => 'one', :two => 'two'}, SubTask.configurations.hash)
#     
#     assert_equal "# BaseTask configuration\none: 1\n", BaseTask.configurations.format_yaml    
#      
#     expected = %Q{
# # BaseTask configuration
# one: one             # the first configuration
# 
# # SubTask configuration
# two: two             # the second configuration
# }
#     assert_equal expected[1..-1], SubTask.configurations.format_yaml
#   end

  #
  # add configurations
  #
  
  class AnotherClass
  end
  
  def test_add
    cc = ClassConfiguration.new
    cc.add(:key, 'value', ClassConfigurationTest)
    
    assert_equal [[:key, 'value', ClassConfigurationTest]], cc.declarations
    assert_equal({:key => 'value'}, cc.hash)
    
    cc.add(:key, 'new value', AnotherClass)  
    assert_equal [
      [:key, 'value', ClassConfigurationTest], 
      [:key, 'new value', AnotherClass]
    ], cc.declarations
    assert_equal({:key => 'new value'}, cc.hash)
  end
  
  def test_add_symbolizes_keys
    cc = ClassConfiguration.new
    cc.add('key', 'value', ClassConfigurationTest)
    
    assert_equal [[:key, 'value', ClassConfigurationTest]], cc.declarations
    assert_equal({:key => 'value'}, cc.hash)
  end

  # def test_add_raises_error_if_declarations_are_not_correct
  #   cc = ClassConfiguration.new
  #   assert_raise(ArgumentError) { cc.add(:key, 'value')}
  #   assert_raise(ArgumentError) { cc.add([:key, 'value'])}
  # end

  #
  # remove configurations
  #
  
  def test_remove
    cc = ClassConfiguration.new(
      [:one, 1, ClassConfigurationTest],
      [:one, 'one', AnotherClass],
      [:two, 'two', AnotherClass],
      [:three, 'three', AnotherClass])
    
    assert_equal 4, cc.declarations.length
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, cc.hash)
    
    cc.remove(:one, :three)
    assert_equal [[:two, 'two', AnotherClass]], cc.declarations  
    assert_equal({:two => 'two'}, cc.hash)
  end
  
  def test_remove_symbolizes_inputs
    cc = ClassConfiguration.new([:key, 'value', ClassConfigurationTest])
    cc.remove('key')
    assert_equal [], cc.declarations
  end

  #
  # merge test
  #
  
  # def test_merge
  #   c1 = ClassConfiguration.new([:one, 1, '', ClassConfigurationTest])
  #   c2 = c1.merge([
  #     [:one, 'one', '', AnotherClass], 
  #     [:two, 'two', '', AnotherClass]])
  #     
  #   assert_not_equal c1.object_id, c2.object_id
  #   
  #   assert_equal [[:one, 1, '', ClassConfigurationTest]], c1.declarations 
  #   assert_equal [
  #     [:one, 1, '', ClassConfigurationTest],
  #     [:one, 'one', '', AnotherClass], 
  #     [:two, 'two', '', AnotherClass]], c2.declarations 
  # end
  

end