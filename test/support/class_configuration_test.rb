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
  
  TO_INT_BLOCK = lambda {|value| value.to_i }
  ECHO_BLOCK = lambda {|value| value }
  
  #
  # initialization test
  #
  
  def test_initialization
    assert_equal Sample, c.receiver
    assert_equal [], c.assignments.to_a
    assert_equal({}, c.default)
    assert_equal({}, c.unprocessed_default)
    assert_equal({}, c.process_blocks)
  end
  
  def test_initialization_with_a_parent
    c.add(:config, "default", &ECHO_BLOCK)
    
    another = ClassConfiguration.new Another, c
    
    assert_equal [[Sample, [:config]]], another.assignments.to_a
    assert_equal({:config => 'default'}, another.default)
    assert_equal({:config => 'default'}, another.unprocessed_default)
    assert_equal({:config => ECHO_BLOCK}, another.process_blocks)
  end
  
  def test_child_is_decoupled_from_parent
    another = ClassConfiguration.new Another, c
    
    c.add(:one, "one", &ECHO_BLOCK)
    another.add(:two, "two", &ECHO_BLOCK)
    
    assert_equal [[Sample, [:one]]], c.assignments.to_a
    assert_equal({:one => 'one'}, c.default)
    assert_equal({:one => 'one'}, c.unprocessed_default)
    assert_equal({:one => ECHO_BLOCK}, c.process_blocks)
    
    assert_equal [[Another, [:two]]], another.assignments.to_a
    assert_equal({:two => 'two'}, another.default)
    assert_equal({:two => 'two'}, another.unprocessed_default)
    assert_equal({:two => ECHO_BLOCK}, another.process_blocks)
  end
  
  #
  # normalize_key test
  #
  
  def test_normalize_key_symbolizes_input
    assert_equal :one, c.normalize_key(:one)
    assert_equal :one, c.normalize_key('one')  
  end
  
  #
  # add test
  #
  
  def test_add_documentation
    c = ClassConfiguration.new Object
    c.add(:a, "1") {|value| value.to_i}
    c.add('b')
  
    assert_equal({:a => 1, :b => nil}, c.default)
    
    c.add(:a, "2")
    c.add(:b, 10) 
    c.add(:b) {|value| value.to_s }
  
    assert_equal({:a => 2, :b => "10"}, c.default)
  end
  
  def test_add_sets_a_config
    c.add :config, "default"
    assert_equal({:config => 'default'}, c.default)
  end
  
  def test_add_normalizes_configs
    c.add :config, "string default"
    c.add 'config', "string default"
    assert_equal({:config => "string default"}, c.default)
  end
  
  def test_add_processes_config_with_block_if_given_and_stores_unprocessed_default
    c.add(:int, "1", &TO_INT_BLOCK) 
    
    assert_equal({:int => 1}, c.default)
    assert_equal({:int => "1"}, c.unprocessed_default)
    assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
  end
  
  def test_the_default_value_for_a_config_is_nil
    c.add :config
    assert_equal({:config => nil}, c.default)
    assert_equal({:config => nil}, c.unprocessed_default)
  end
  
  def test_add_overrides_current_config
    c.add :config, "current"
    c.add :config, "new"
    assert_equal({:config => "new"}, c.default)
  end
  
  def test_new_blocks_reevaluate_existing_values
    c.add(:int, "1")
    assert_equal({:int => "1"}, c.default)
    assert_equal({:int => "1"}, c.unprocessed_default)
    
    c.add(:int, &TO_INT_BLOCK) 
    assert_equal({:int => 1}, c.default)
    assert_equal({:int => "1"}, c.unprocessed_default)
  end
  
  def test_new_values_are_evaluated_with_existing_block
    c.add(:int, "1", &TO_INT_BLOCK) 
    assert_equal({:int => 1}, c.default)
    assert_equal({:int => "1"}, c.unprocessed_default)
    
    c.add(:int, "2") 
    assert_equal({:int => 2}, c.default)
    assert_equal({:int => "2"}, c.unprocessed_default)
  end
  
  def test_the_current_unprocessed_default_and_process_block_may_be_overridden_separately
    c.add(:int, "1", &TO_INT_BLOCK) 
    assert_equal({:int => "1"}, c.unprocessed_default)
    assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
    
    c.add(:int) 
    assert_equal({:int => "1"}, c.unprocessed_default)
    assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
    
    c.add(:int, "2") 
    assert_equal({:int => "2"}, c.unprocessed_default)
    assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
    
    c.add(:int, &ECHO_BLOCK) 
    assert_equal({:int => "2"}, c.unprocessed_default)
    assert_equal({:int => ECHO_BLOCK}, c.process_blocks)
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
    c.add(:one, "one", &ECHO_BLOCK)
    c.add(:two, "two", &ECHO_BLOCK)
    
    assert_equal({:one => 'one', :two => "two"}, c.default)
    assert_equal({:one => 'one', :two => "two"}, c.unprocessed_default)
    assert_equal({:one => ECHO_BLOCK, :two => ECHO_BLOCK}, c.process_blocks)
      
    c.remove :one
    assert_equal({:two => "two"}, c.default)
    assert_equal({:two => "two"}, c.unprocessed_default)
    assert_equal({:two => ECHO_BLOCK}, c.process_blocks)
    
    c.remove :two
    assert_equal({}, c.default)
    assert_equal({}, c.unprocessed_default)
    assert_equal({}, c.process_blocks)
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
  # merge test
  #
  
  def test_merge_documentation
    a = ClassConfiguration.new 'ClassOne'
    a.add(:one, "one") 
  
    b = ClassConfiguration.new 'ClassTwo'
    b.add(:two, "two")
  
    a.merge!(b)
    assert_equal({:one => "one", :two => "two"}, a.default)
  
    c = ClassConfiguration.new 'ClassThree'
    c.add(:one)
  
    assert_equal 'ClassThree', c.assignments.key_for(:one)
    assert_equal 'ClassOne', a.assignments.key_for(:one)
  
    assert_raise(ArgumentError) { a.merge!(c) }
  end
  
  def test_merge_adds_configs_of_another_to_self
    another = ClassConfiguration.new Another
    another.add(:one, "1", &TO_INT_BLOCK)
    
    c.merge!(another)
    assert_equal({:one => 1}, c.default)
    assert_equal({:one => "1"}, c.unprocessed_default)
    assert_equal({:one => TO_INT_BLOCK}, c.process_blocks)
  end
  
  def test_merge_overwrites_existing_block_and_value
    c.add(:one, "1")
    c.add(:two, "2", &TO_INT_BLOCK)
    
    another = ClassConfiguration.new Sample
    another.add(:one, "one", &ECHO_BLOCK)
    another.add(:two, "two", &ECHO_BLOCK)
    
    another.merge!(c)
    
    assert_equal({:one => "1", :two => 2}, another.default)
    assert_equal({:one => "1", :two => "2"}, another.unprocessed_default)
    assert_equal({:two => TO_INT_BLOCK}, another.process_blocks)
  end
  
  def test_merge_preserves_assignments
    c.add(:one)
    
    another = ClassConfiguration.new Another
    another.add(:two)
    
    c.merge!(another)
    assert_equal [[Sample, [:one]], [Another, [:two]]], c.assignments.to_a
  end
  
  def test_merge_overwrites_existing_configs_if_the_declaration_class_is_consistent
    parent = ClassConfiguration.new Sample
    parent.add(:one, 0)
    
    another = ClassConfiguration.new Another, parent
    another.add(:one, 1)
    another.add(:two, 2)
    
    target = ClassConfiguration.new Sample
    target.add(:one, 3)
    target.merge!(another)
    
    assert_equal({:one => 1, :two => 2}, target.default)
    assert_equal [[Sample, [:one]], [Another, [:two]]], target.assignments.to_a
  end
  
  def test_merge_raises_error_if_declaration_class_for_a_merged_config_is_in_conflict
    another = ClassConfiguration.new Another
    another.add(:one)
    c.add(:one)
    
    assert_raise(ArgumentError) { c.merge!(another) }
  end
  
  def test_merge_yields_newly_added_keys_if_block_is_given
    parent = ClassConfiguration.new Sample
    parent.add(:one)
    
    child1 = ClassConfiguration.new Another, parent
    child1.add(:two)
    child1.add(:three)
    
    child2 = ClassConfiguration.new Another, parent
    
    keys = []
    child2.merge!(child1) do |key|
      keys << key
    end
    
    assert_equal [:two, :three], keys
  end
  
  #
  # process test
  #
  
  def test_process_sends_input_to_process_block_if_specified
    was_in_block = false
    c.add(:one) do |input|
      was_in_block = true
      input.to_s
    end
    
    assert_equal "1", c.process(:one, 1)
    assert was_in_block
  end
  
  def test_process_returns_input_if_no_process_block_is_specified
    assert_nil c.process_blocks[:one]
    
    assert_equal 'one', c.process(:one, 'one')
    assert_equal 1, c.process(:one, 1)
    assert_equal nil, c.process(:one, nil)
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