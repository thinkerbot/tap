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
    assert_equal({}, c.map)
  end
  
  def test_initialization_with_a_parent
    c.add(:config, :default => "default")
    
    another = ClassConfiguration.new Another, c
    
    assert_equal [[Sample, [:config]]], another.assignments.to_a
    assert_equal({:config => Configuration.new(:config, "default")}, c.map)
  end
  
  def test_child_is_decoupled_from_parent
    c.add(:one, :default => "one")
    another = ClassConfiguration.new Another, c
    
    c[:one].default = "ONE"
    c.add(:two, :default => "TWO")  
    another.add(:two, :default => "two")
    
    assert_equal [[Sample, [:one, :two]]], c.assignments.to_a
    assert_equal({
      :one => Configuration.new(:one, "ONE"),
      :two => Configuration.new(:two, "TWO")
    }, c.map)

    assert_equal [[Sample, [:one]], [Another, [:two]]], another.assignments.to_a
    assert_equal({
      :one => Configuration.new(:one, "one"),
      :two => Configuration.new(:two, "two")
    }, another.map)
  end
  
  #
  # add test
  #
  
  # def test_add_documentation
  #   c = ClassConfiguration.new Object
  #   c.add(:a, :default => 'default')
  #   c.add('b')
  #   assert_equal({:a => 'default', :b => nil}, c.default)
  # end
  
  def test_adds_or_updates_the_specified_config_in_map
    c.add :config, :default => "default"
    assert_equal({:config => Configuration.new(:config, "default")}, c.map)
    
    c[:config].name = 'alt'
    c.add :config, :default => "alt default"
    assert_equal({:config => Configuration.new('alt', "alt default", :mandatory, :config, :config=)}, c.map)
  end
  
  def test_add_symbolizes_keys
    c.add :config, :default => "symbol default"
    c.add 'config', :default => "string default"
    assert_equal({:config => Configuration.new(:config, "string default")}, c.map)
  end
  
  def test_the_default_value_for_a_config_is_nil
    c.add :config
    assert_equal({:config => Configuration.new(:config, nil)}, c.map)
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
  
  def test_remove_removes_config_from_map
    c.add(:one)
    c.add(:two)
    
    assert_equal({
      :one => Configuration.new(:one),
      :two => Configuration.new(:two)
    }, c.map)

    c.remove :one
    assert_equal({:two => Configuration.new(:two)}, c.map)

    c.remove :two
    assert_equal({}, c.map)
  end
  
  def test_remove_symbolizes_keys
    c.add(:one)
    assert_equal({:one => Configuration.new(:one)}, c.map)

    c.remove 'one'
    assert_equal({}, c.map)
  end
  
  def test_remove_does_not_raise_an_error_for_unknown_configs
    assert_nothing_raised { c.remove :non_existant }
  end
  
  def test_remove_removes_keys_from_assignments
    c.add(:one)
    c.add(:two)
    
    c.remove(:one)
    assert_equal [[Sample, [:two]]], c.assignments.to_a
    
    c.remove(:two)
    assert_equal [[Sample, []]], c.assignments.to_a
  end
  
  def test_removal_does_not_affect_parent
    c.add(:one)
    another = ClassConfiguration.new Another, c
    
    another.remove(:one)
    
    assert_equal({:one => Configuration.new(:one)}, c.map)
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    
    assert_equal({}, another.map)
    assert_equal [[Sample, []]], another.assignments.to_a
  end

  #
  # key? test
  #
  
  def test_key_is_true_if_key_is_a_config_key
    c.add(:key)
    assert c.key?(:key)
    assert !c.key?('key')
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
  # each test
  #
  
  def test_each_yields_each_receiver_key_config
    c.add(:one)
    c.add(:two)
    another = ClassConfiguration.new Another, c
    another.add(:three)
    
    results = []
    another.each {|receiver, key, config| results << [receiver, key, config]}
    
    assert_equal [[Sample, :one, Configuration.new(:one)],[Sample, :two, Configuration.new(:two)],[Another, :three, Configuration.new(:three)]], results
  end
  
  # 
  # each_pair test
  #
  
  def test_each_pair_returns_yields_each_key_config_pair
    c.add(:one)
    c.add(:two)
    another = ClassConfiguration.new Another, c
    another.add(:three)
    
    results = []
    another.each_pair {|key, config| results << [key, config]}
    
    assert_equal [[:one, Configuration.new(:one)],[:two, Configuration.new(:two)],[:three, Configuration.new(:three)]], results
  end
  
  #
  # instance_config test
  #
  
  def test_instance_config_returns_new_instance_config_set_to_self
    assert_equal c, c.instance_config.class_config
  end
  
  def test_instance_config_returns_new_instance_config_bound_to_receiver
    s = Sample.new
    config = c.instance_config(s)
    assert_equal s, config.receiver
    assert config.bound? 
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