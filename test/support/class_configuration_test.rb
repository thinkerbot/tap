require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ClassConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetMethods
  
  class Sample
  end
  
  class Another
  end
  
  attr_reader :c
  
  def setup
    @c = ClassConfiguration.new Sample
  end
  
  #
  # initialization test
  #
  
  def test_initialization
    assert_equal Sample, c.receiver
    assert_equal [], c.assignments.to_a
    assert_equal({}, c.default)
    assert_equal({}, c.map)
  end
  
  def test_initialization_with_a_parent
    c.add(:config, "default")
    
    another = ClassConfiguration.new Another, c
    
    assert_equal [[Sample, [:config]]], another.assignments.to_a
    assert_equal({:config => 'default'}, another.default)
    assert_equal({:config => :config=}, c.map)
  end
  
  def test_child_is_decoupled_from_parent
    another = ClassConfiguration.new Another, c
    
    c.add(:one, "one")
    another.add(:two, "two")
    
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    assert_equal({:one => 'one'}, c.default)
    assert_equal({:one => :one=}, c.map)

    assert_equal [[Another, [:two]]], another.assignments.to_a
    assert_equal({:two => 'two'}, another.default)
    assert_equal({:two => :two=}, another.map)
  end
  
  #
  # default test
  #
  
  # def test_default_with_duplicate_false_returns_default
  #   assert_equal c.default.object_id, c.instance_variable_get(:@default).object_id
  # end
  # 
  # def test_default_with_duplicate_true_returns_duplicate_with_all_Array_and_Hash_values_duplicated
  #   c.add(:array, [])
  #   c.add(:hash, {})
  #   c.add(:obj, Object.new)
  #   
  #   duplicate = c.default(true)
  #   
  #   assert_equal c.default, duplicate
  #   assert_not_equal c.default.object_id, duplicate.object_id
  #   
  #   assert_equal c.default[:array], duplicate[:array]
  #   assert_not_equal c.default[:array].object_id, duplicate[:array].object_id
  #   
  #   assert_equal c.default[:hash], duplicate[:hash]
  #   assert_not_equal c.default[:hash].object_id, duplicate[:hash].object_id
  #   
  #   assert_equal c.default[:obj], duplicate[:obj]
  #   assert_equal c.default[:obj].object_id, duplicate[:obj].object_id
  # end
  
  #
  # has_config? test
  #
  
  # def test_has_config_returns_true_if_the_normalized_key_is_assigned
  #   c.add(:config)
  # 
  #   assert c.has_config?(:config)
  #   assert c.has_config?('config')
  #   assert !c.has_config?(:undeclared)
  #   
  #   c.remove(:config)
  #   assert c.has_config?(:config)
  #   
  #   c.remove(:config, true)
  #   assert !c.has_config?(:config)
  # end
  
  #
  # add test
  #
  
  def test_add_documentation
    c = ClassConfiguration.new Object
    c.add(:a, 'default')
    c.add('b')
    assert_equal({:a => 'default', :b => nil}, c.default)
  end
  
  def test_add_sets_the_config_default
    c.add :config, "default"
    assert_equal({:config => 'default'}, c.default)
  end
  
  def test_add_inserts_setter_into_map
    c.add :config
    assert_equal({:config => :config=}, c.map)
  end
  
  def test_add_symbolizes_keys
    c.add :config, "string default"
    c.add 'config', "string default"
    assert_equal({:config => "string default"}, c.default)
  end
  
  def test_the_default_value_for_a_config_is_nil
    c.add :config
    assert_equal({:config => nil}, c.default)
  end
  
  def test_add_overrides_current_default
    c.add :config, "current"
    c.add :config, "new"
    assert_equal({:config => "new"}, c.default)
  end
  
  def test_add_adds_new_configs_to_assignments_keyed_by_receiver
    c.add(:int)
    assert_equal [[Sample, [:int]]], c.assignments.to_a
  end
  
  def test_does_not_add_existing_configs_to_assignments
    c.add(:one)
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    
    another = ClassConfiguration.new Another, c
    
    another.add(:one)
    another.add(:two)
    assert_equal [[Sample, [:one]], [Another, [:two]]], another.assignments.to_a
  end
  
  #
  # remove test
  #
  
  def test_remove_removes_a_config
    c.add(:one, "one")
    c.add(:two, "two")
    
    assert_equal({:one => 'one', :two => "two"}, c.default)

    c.remove :one
    assert_equal({:two => "two"}, c.default)

    c.remove :two
    assert_equal({}, c.default)
  end
  
  def test_remove_symbolizes_keys
    c.add(:one, "one")
    assert_equal({:one => 'one'}, c.default)

    c.remove 'one'
    assert_equal({}, c.default)
  end
  
  def test_remove_removes_setter_from_map
    c.add(:one)
    assert_equal({:one => :one=}, c.map)

    c.remove :one
    assert_equal({}, c.map)
  end
  
  def test_remove_does_not_raise_an_error_for_unknown_configs
    assert_nothing_raised { c.remove :non_existant }
  end
  
  def test_does_not_remove_configs_from_assignments_unless_specified
    c.add(:one)
    c.add(:two)
    c.remove(:one)
    assert_equal [[Sample, [:one, :two]]], c.assignments.to_a
    
    c.remove(:one, true)
    assert_equal [[Sample, [:two]]], c.assignments.to_a
    
    c.remove(:two, true)
    assert_equal [[Sample, []]], c.assignments.to_a
  end
  
  def test_removal_does_not_affect_parent
    c.add(:one)
    another = ClassConfiguration.new Another, c
    
    another.remove(:one, true)
    
    assert_equal({:one => nil}, c.default)
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    
    assert_equal({}, another.default)
    assert_equal [[Sample, []]], another.assignments.to_a
  end

  #
  # key? test
  #
  
  def test_key_is_true_if_key_is_a_config_key
    c.add(:key)
    assert c.key?(:key)
    assert c.key?('key')
  end
  
  def test_key_does_not_symbolize_unless_specified
    c.add(:key)
    assert !c.key?('key', false)
  end

  #
  # keys test
  #
  
  def test_keys_returns_all_config_keys
    c.add(:one)
    c.add(:two)
    c.add(:three)
    assert_equal([:one, :two, :three].sort_by {|k| k.to_s }, c.keys.sort_by {|k| k.to_s })
  end

  #
  # ordered_keys test
  #
  
  def test_ordered_keys_returns_all_config_keys_in_order
    c.add(:one)
    c.add(:two)
    c.add(:three)
    assert_equal([:one, :two, :three], c.ordered_keys)
  end
  
  #
  # setter test
  #
  
  def test_setter_returns_the_setter_method_for_the_mapped_key
    c.add(:key)
    assert_equal :key=, c.setter(:key)
  end
  
  def test_setter_raises_error_for_unmapped_keys
    assert_raise(ArgumentError) { c.setter(:unmapped) }
  end

  #
  # default_value test
  #
  
  def test_default_value_returns_mapped_default_value
    c.add(:key)
    assert_equal nil, c.default_value(:key)
    
    c.add(:key, 'value')
    assert_equal 'value', c.default_value(:key)
  end
  
  def test_default_value_raises_error_if_key_is_not_a_config
    assert_raise(ArgumentError) { c.default_value(:key) }
  end
  
  def test_default_value_duplicates_values
    a = [1,2,3]
    c.add(:array, a)
    
    assert_equal a, c.default_value(:array)
    assert_not_equal a.object_id, c.default_value(:array)
  end
  
  def test_default_value_does_not_duplicate_if_specified
    a = [1,2,3]
    c.add(:array, a)
    
    assert_equal a, c.default_value(:array, false)
    assert_not_equal a.object_id, c.default_value(:array, false)
  end
  
  # 
  # each_assignment test
  #
  
  def test_each_assignment_yields_each_receiver_key_pair
    c.add(:one)
    c.add(:two)
    another = ClassConfiguration.new Another, c
    another.add(:three)
    
    results = []
    another.each_assignment {|receiver,key| results << [receiver,key]}
    
    assert_equal [[Sample, :one],[Sample, :two],[Another, :three]], results
  end
  
  # 
  # each_map test
  #
  
  def test_each_map_returns_yields_each_getter_setter_pair
    c.add(:one)
    c.add(:two)
    another = ClassConfiguration.new Another, c
    another.add(:three)
    
    results = []
    another.each_map {|getter, setter| results << [getter, setter]}
    
    assert_equal [[:one, :one=],[:two, :two=],[:three, :three=]], results
  end
  
  #
  # instance_config test
  #
  
  def test_instance_config_returns_new_instance_config_bound_to_self
    assert_equal c, c.instance_config.class_config
  end
  
  def test_instance_config_is_set_with_duplicate_default_values_for_self
    c.add(:one, 'one')
    c.add(:two, ['two'])
    
    config = c.instance_config
    assert_equal({:one => 'one', :two => ['two']}, config)
    assert_not_equal(c.default[:two].object_id, config[:two].object_id)
  end
  
  #
  # format_str tests
  #
  
  class FormatYamlClass
    include Tap::Support::Configurable

    class << self
      def source_files
        [__FILE__]
      end
    end

    config :trailing, 'trailing value'  # trailing comment

    # leading comment
    config :leading, 'leading value'

    # Line one of a long multiline leading comment
    # Line two of a long multiline leading comment
    # Line three of a long multiline leading comment
    config :long_leading, 'long_leading value'

    # leading of leading_and_trailing comment
    config :leading_and_trailing, 'leading_and_trailing value'  # trailing of leading_and_trailing comment

    config :no_comment, 'no_comment value'

    config :nil_config, nil
  end

  class FormatYamlSubClass < FormatYamlClass
    config :trailing, 'new trailing value'  # new trailing comment
    # subclass_config comment
    config :subclass_config, 'subclass_config value'  
    config :nil_config, 'no longer nil value'
    config :no_comment, nil
  end
  
  def test_format_str
    extended_test do 
      cc = FormatYamlClass.configurations
      assert ClassConfiguration, cc.class

      expected = %Q{
###############################################################################
# ClassConfigurationTest::FormatYamlClass configurations
###############################################################################

# trailing comment
trailing: trailing value

# leading comment
leading: leading value

# Line one of a long multiline leading comment
# Line two of a long multiline leading comment
# Line three of a long multiline leading comment
long_leading: long_leading value

# leading of leading_and_trailing comment
# trailing of leading_and_trailing comment
leading_and_trailing: leading_and_trailing value

no_comment: no_comment value

#nil_config: 

}
    
      assert_equal expected[1..-1], cc.format_str
    
      expected_without_doc = %Q{
###############################################################################
# ClassConfigurationTest::FormatYamlClass configurations
###############################################################################
trailing: trailing value
leading: leading value
long_leading: long_leading value
leading_and_trailing: leading_and_trailing value
no_comment: no_comment value
#nil_config: 

}
      assert_equal expected_without_doc[1..-1], cc.format_str(:nodoc)
    
      cc = FormatYamlSubClass.configurations
      assert ClassConfiguration, cc.class
    
      expected = %Q{
###############################################################################
# ClassConfigurationTest::FormatYamlClass configurations
###############################################################################

# trailing comment
trailing: new trailing value

# leading comment
leading: leading value

# Line one of a long multiline leading comment
# Line two of a long multiline leading comment
# Line three of a long multiline leading comment
long_leading: long_leading value

# leading of leading_and_trailing comment
# trailing of leading_and_trailing comment
leading_and_trailing: leading_and_trailing value

#no_comment: 

nil_config: no longer nil value

###############################################################################
# ClassConfigurationTest::FormatYamlSubClass configuration
###############################################################################

# subclass_config comment
subclass_config: subclass_config value

}

      assert_equal expected[1..-1], cc.format_str

      expected_without_doc = %Q{
###############################################################################
# ClassConfigurationTest::FormatYamlClass configurations
###############################################################################
trailing: new trailing value
leading: leading value
long_leading: long_leading value
leading_and_trailing: leading_and_trailing value
#no_comment: 
nil_config: no longer nil value

###############################################################################
# ClassConfigurationTest::FormatYamlSubClass configuration
###############################################################################
subclass_config: subclass_config value

}
      assert_equal expected_without_doc[1..-1], cc.format_str(:nodoc)
    end
  end
  
end