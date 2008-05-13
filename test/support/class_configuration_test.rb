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
  end
  
  def test_initialization_with_a_parent
    c.add(:config, "default")
    
    another = ClassConfiguration.new Another, c
    
    assert_equal [[Sample, [:config]]], another.assignments.to_a
    assert_equal({:config => 'default'}, another.default)
  end
  
  def test_child_is_decoupled_from_parent
    another = ClassConfiguration.new Another, c
    
    c.add(:one, "one")
    another.add(:two, "two")
    
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    assert_equal({:one => 'one'}, c.default)

    assert_equal [[Another, [:two]]], another.assignments.to_a
    assert_equal({:two => 'two'}, another.default)
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
  
  def test_has_config_returns_true_if_the_normalized_key_is_assigned
    c.add(:config)

    assert c.has_config?(:config)
    assert c.has_config?('config')
    assert !c.has_config?(:undeclared)
    
    c.remove(:config)
    assert c.has_config?(:config)
    
    c.remove(:config, true)
    assert !c.has_config?(:config)
  end
  
  #
  # add test
  #
  
  # def test_add_documentation
  #   c = ClassConfiguration.new Object
  #   c.add(:a, "1") {|value| value.to_i}
  #   c.add('b')
  # 
  #   assert_equal({:a => 1, :b => nil}, c.default)
  #   
  #   c.add(:a, "2")
  #   c.add(:b, 10) 
  #   c.add(:b) {|value| value.to_s }
  # 
  #   assert_equal({:a => 2, :b => "10"}, c.default)
  # end
  
  def test_add_sets_the_config_default
    c.add :config, "default"
    assert_equal({:config => 'default'}, c.default)
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
  
  # TODO
  # each test
  #
  
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