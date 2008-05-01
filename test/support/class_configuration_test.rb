require  File.join(File.dirname(__FILE__), '../tap_test_helper')

# for documentation test
# class BaseTask 
#   include Tap::Support::Framework
#   config :one, 1
# end
# class SubTask < BaseTask
#   config :one, 'one'
#   config :two, 'two'
# end
# class MergeTask < BaseTask
#   config :three, 'three'
#   config_merge SubTask
# end
# class ValidationTask < Tap::Task
#   config :one, 'one', &c.check(String)
#   config :two, 'two', &c.yaml(/two/, Integer)
#   config :three, 'three' do |v| 
#     v =~ /three/ ? v.upcase : raise("not three")
#   end
# end
# 
# class FormatYamlClass
#   include Tap::Support::Configurable
#   
#   class << self
#     def source_files
#       [__FILE__]
#     end
#   end
#   
#   config :trailing, 'trailing value'  # trailing comment
#   
#   # leading comment
#   config :leading, 'leading value'
#   
#   # Line one of a long multiline leading comment
#   # Line two of a long multiline leading comment
#   # Line three of a long multiline leading comment
#   config :long_leading, 'long_leading value'
#   
#   # leading of leading_and_trailing comment
#   config :leading_and_trailing, 'leading_and_trailing value'  # trailing of leading_and_trailing comment
#   
#   config :no_comment, 'no_comment value'
#   
#   config :nil_config, nil
# end
# 
# class FormatYamlSubClass < FormatYamlClass
#   config :trailing, 'new trailing value'  # new trailing comment
#   # subclass_config comment
#   config :subclass_config, 'subclass_config value'  
#   config :nil_config, 'no longer nil value'
#   config :no_comment, nil
# end

class ClassConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  
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
  
  # def test_initialization
  #   assert_equal Sample, c.receiver
  #   assert_equal [], c.declarations
  #   assert_equal [[Sample, []]], c.declarations_array
  #   assert_equal({}, c.default)
  #   assert_equal({}, c.unprocessed_default)
  #   assert_equal({}, c.process_blocks)
  # end
  # 
  # def test_initialization_with_a_parent_inherits_configs
  #   c.add(:config, "default", &ECHO_BLOCK)
  #   
  #   another = ClassConfiguration.new Another, c
  #   
  #   assert_equal [], another.declarations
  #   assert_equal [[Sample, [:config]], [Another, []]], another.declarations_array
  #   assert_equal({:config => 'default'}, another.default)
  #   assert_equal({:config => 'default'}, another.unprocessed_default)
  #   assert_equal({:config => ECHO_BLOCK}, another.process_blocks)
  # end
  # 
  # def test_child_is_decoupled_from_parent
  #   another = ClassConfiguration.new Another, c
  #   
  #   c.add(:one, "one", &ECHO_BLOCK)
  #   another.add(:two, "two", &ECHO_BLOCK)
  #   
  #   assert_equal [:one], c.declarations
  #   assert_equal [[Sample, [:one]]], c.declarations_array
  #   assert_equal({:one => 'one'}, c.default)
  #   assert_equal({:one => 'one'}, c.unprocessed_default)
  #   assert_equal({:one => ECHO_BLOCK}, c.process_blocks)
  #   
  #   assert_equal [:two], another.declarations
  #   assert_equal [[Sample, []], [Another, [:two]]], another.declarations_array
  #   assert_equal({:two => 'two'}, another.default)
  #   assert_equal({:two => 'two'}, another.unprocessed_default)
  #   assert_equal({:two => ECHO_BLOCK}, another.process_blocks)
  # end
  # 
  # #
  # # add test
  # #
  # 
  # def test_add_documentation
  #   c = ClassConfiguration.new Object
  #   c.add(:config, "1") {|value| value.to_i}
  #   c.add('no_value_specified')
  #   assert_equal({:config => 1, :no_value_specified => nil}, c.default)
  # 
  #   c.add(:config, "2")
  #   c.add(:no_value_specified, 10) {|value| value.to_s }
  #   assert_equal({:config => 2, :no_value_specified => "10"}, c.default)
  # end
  # 
  # def test_add_sets_a_config
  #   c.add :config, "default"
  #   assert_equal({:config => 'default'}, c.default)
  # end
  # 
  # def test_add_symbolizes_configs
  #   c.add :config, "string default"
  #   c.add 'config', "string default"
  #   assert_equal({:config => "string default"}, c.default)
  # end
  # 
  # def test_add_processes_config_with_block_if_given_and_stores_unprocessed_default
  #   c.add(:int, "1", &TO_INT_BLOCK) 
  #   
  #   assert_equal({:int => 1}, c.default)
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  #   assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
  # end
  # 
  # def test_the_default_value_for_a_config_is_nil
  #   c.add :config
  #   assert_equal({:config => nil}, c.default)
  # end
  # 
  # def test_add_overrides_current_config
  #   c.add :config, "current"
  #   c.add :config, "new"
  #   assert_equal({:config => "new"}, c.default)
  # end
  # 
  # def test_new_blocks_reevaluate_existing_values
  #   c.add(:int, "1")
  #   assert_equal({:int => "1"}, c.default)
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  #   
  #   c.add(:int, &TO_INT_BLOCK) 
  #   assert_equal({:int => 1}, c.default)
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  # end
  # 
  # def test_new_values_are_evaluated_with_existing_block
  #   c.add(:int, "1", &TO_INT_BLOCK) 
  #   assert_equal({:int => 1}, c.default)
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  #   
  #   c.add(:int, "2") 
  #   assert_equal({:int => 2}, c.default)
  #   assert_equal({:int => "2"}, c.unprocessed_default)
  # end
  # 
  # def test_unless_specified_the_current_unprocessed_default_and_process_block_are_not_overridden
  #   c.add(:int, "1", &TO_INT_BLOCK) 
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  #   assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
  #   
  #   c.add(:int) 
  #   assert_equal({:int => "1"}, c.unprocessed_default)
  #   assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
  #   
  #   c.add(:int, "2") 
  #   assert_equal({:int => "2"}, c.unprocessed_default)
  #   assert_equal({:int => TO_INT_BLOCK}, c.process_blocks)
  #   
  #   c.add(:int, &ECHO_BLOCK) 
  #   assert_equal({:int => "2"}, c.unprocessed_default)
  #   assert_equal({:int => ECHO_BLOCK}, c.process_blocks)
  # end
  # 
  # def test_add_adds_new_configs_to_declarations
  #   c.add(:int)
  #   assert_equal [:int], c.declarations
  #   assert_equal [[Sample, [:int]]], c.declarations_array
  #   
  #   c.add(:int)
  #   assert_equal [:int], c.declarations
  #   assert_equal [[Sample, [:int]]], c.declarations_array
  # end
  # 
  # def test_does_not_add_existing_configs_to_declarations
  #   c.add(:one)
  #   assert_equal [:one], c.declarations
  #   assert_equal [[Sample, [:one]]], c.declarations_array
  #   
  #   another = ClassConfiguration.new Another, c
  #   
  #   another.add(:one)
  #   another.add(:two)
  #   assert_equal [:two], another.declarations
  #   assert_equal [[Sample, [:one]], [Another, [:two]]], another.declarations_array
  # end
  # 
  # #
  # # remove test
  # #
  # 
  # def test_remove_removes_a_config
  #   c.add(:one, "one", &ECHO_BLOCK)
  #   c.add(:two, "two", &ECHO_BLOCK)
  #   
  #   assert_equal({:one => 'one', :two => "two"}, c.default)
  #   assert_equal({:one => 'one', :two => "two"}, c.unprocessed_default)
  #   assert_equal({:one => ECHO_BLOCK, :two => ECHO_BLOCK}, c.process_blocks)
  #     
  #   c.remove :one
  #   assert_equal({:two => "two"}, c.default)
  #   assert_equal({:two => "two"}, c.unprocessed_default)
  #   assert_equal({:two => ECHO_BLOCK}, c.process_blocks)
  #   
  #   c.remove :two
  #   assert_equal({}, c.default)
  #   assert_equal({}, c.unprocessed_default)
  #   assert_equal({}, c.process_blocks)
  # end
  # 
  # def test_remove_does_not_raise_an_error_for_unknown_configs
  #   assert_nothing_raised { c.remove :non_existant }
  # end
  # 
  # def test_does_not_remove_configs_from_declarations_unless_specified
  #   c.add(:one)
  #   c.remove(:one)
  #   assert_equal [:one], c.declarations
  #   assert_equal [[Sample, [:one]]], c.declarations_array
  #   
  #   c.remove(:one, true)
  #   assert_equal [], c.declarations
  #   assert_equal [[Sample, []]], c.declarations_array
  # end
  # 
  # def test_removal_does_not_affect_parent
  #   c.add(:one)
  #   another = ClassConfiguration.new Another, c
  #   
  #   another.remove(:one)
  #   another.remove(:one, true)
  #   
  #   assert_equal({:one => nil}, c.default)
  #   assert_equal [:one], c.declarations
  #   assert_equal [[Sample, [:one]]], c.declarations_array
  #   
  #   assert_equal({}, another.default)
  #   assert_equal [], another.declarations
  #   assert_equal [[Sample, []], [Another, []]], another.declarations_array
  # end
  # 
  # #
  # # declared? test
  # #
  # 
  # def test_declared_returns_true_if_the_config_is_declared_somewhere_in_inheritance_hierarchy
  #   c.add(:one)
  #   another = ClassConfiguration.new Another, c
  #   another.add(:two)
  #   
  #   assert c.declared?(:one)
  #   assert !c.declared?(:two)
  # 
  #   assert another.declared?(:one)
  #   assert another.declared?(:two)
  #   assert !another.declared?(:three)
  # end
  # 
  # #
  # # declaration class
  # #
  # 
  # def test_declaration_class_returns_the_class_declaring_the_config
  #   c.add(:one)
  #   another = ClassConfiguration.new Another, c
  #   another.add(:two)
  #   
  #   assert_equal Sample, c.declaration_class(:one)
  #   assert_equal Sample, another.declaration_class(:one)
  #   assert_equal Another, another.declaration_class(:two)
  # end
  # 
  # def test_declaration_class_returns_nil_for_undeclared_configs
  #   assert_nil c.declaration_class(:non_existant)
  # end
  # 
  # #
  # # declarations_for test
  # #
  # 
  # def test_declarations_for_returns_declarations_for_specified_receiver
  #   c.add(:one)
  #   another = ClassConfiguration.new Another, c
  #   another.add(:two)
  #   another.add(:three)
  #   
  #   assert_equal [], c.declarations_for(Object)
  #   assert_equal [:one], c.declarations_for(Sample)
  #   assert_equal [:one], another.declarations_for(Sample)
  #   assert_equal [:two, :three], another.declarations_for(Another)
  # end

  #
  # merge test
  #
  
  # def test_merge_adds_another_configs_to_self
  #   another = ClassConfiguration.new Another
  #   another.add(:one, "1", &TO_INT_BLOCK)
  #   
  #   c.merge(another)
  #   assert_equal({:one => 1}, c.default)
  #   assert_equal({:one => "1"}, c.unprocessed_default)
  #   assert_equal({:one => TO_INT_BLOCK}, c.process_blocks)
  # end
  # 
  # def test_merge_overwrites_existing_block_and_value
  #   c.add(:one, "1")
  #   c.add(:two, "2", &TO_INT_BLOCK)
  #   
  #   another = ClassConfiguration.new Sample
  #   another.add(:one, "one", &ECHO_BLOCK)
  #   another.add(:two, "two", &ECHO_BLOCK)
  #   
  #   another.merge(c)
  #   
  #   assert_equal({:one => "1", :two => 2}, another.default)
  #   assert_equal({:one => "1", :two => "2"}, another.unprocessed_default)
  #   assert_equal({:two => TO_INT_BLOCK}, another.process_blocks)
  # end
  # 
  # def test_merge_preserves_declarations
  #   another = ClassConfiguration.new Another
  #   another.add(:one)
  #   
  #   c.merge(another)
  #   assert_equal [], c.declarations
  #   assert_equal [[Sample, []], [Another, [:one]]], c.declarations_array
  # end
  # 
  # def test_merge_overwrites_existing_configs_if_the_declaration_class_is_consistent
  #   parent = ClassConfiguration.new Sample
  #   parent.add(:one, 0)
  #   
  #   another = ClassConfiguration.new Another, parent
  #   another.add(:one, 1)
  #   another.add(:two, 2)
  #   
  #   target = ClassConfiguration.new Sample
  #   target.add(:one, 3)
  #   target.merge(another)
  #   
  #   assert_equal({:one => 1, :two => 2}, target.default)
  #   assert_equal [:one], target.declarations
  #   assert_equal [[Sample, [:one]], [Another, [:two]]], target.declarations_array
  # end
  # 
  # def test_merge_raises_error_if_declaration_class_for_a_merged_config_is_in_conflict
  #   another = ClassConfiguration.new Another
  #   another.add(:one)
  #   c.add(:one)
  #   
  #   assert_raise(RuntimeError) { c.merge(another) }
  # end
  
  
#   def test_config_merge
#     t = MergeTask.new
#     assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.config)
#     assert t.respond_to?(:two)
#     yaml = MergeTask.configurations.format_yaml
#     expected = %Q{
# ###############################################################################
# # BaseTask configuration
# ###############################################################################
# one: one
# 
# ###############################################################################
# # MergeTask configuration
# ###############################################################################
# three: three
# 
# ###############################################################################
# # SubTask configuration
# ###############################################################################
# two: two
# }
# 
#     assert_equal expected[1..-1], yaml
#     assert_equal({'one' => 'one', 'two' => 'two', 'three' => 'three'}, YAML.load(yaml))
#   end
#   
#   def test_config_validations
#     t = ValidationTask.new
#     assert_equal({:one => 'one', :two => 'two', :three => 'THREE'}, t.config)
#     
#     t.one = 'two'
#     assert_equal 'two', t.one  
#     assert_raise(Validation::ValidationError) { t.one = 1 }
#     
#     t.two = "two"
#     assert_equal 'two', t.two
#     t.two = 2
#     assert_equal 2, t.two    
#     t.two = "2"
#     assert_equal 2, t.two
#     assert_raise(Validation::ValidationError) { t.two = 'three' }
#     assert_raise(Validation::ValidationError) { t.two = 2.2 }
#     
#     t.three = "three"
#     assert_equal 'THREE', t.three
#     assert_raise(RuntimeError) { t.three = 'THREE' } 
#   end

  #
  # format_yaml tests
  #
  
#   def test_format_yaml
#     cc = FormatYamlClass.configurations
#     assert ClassConfiguration, cc.class
# 
#     expected = %Q{
# ###############################################################################
# # FormatYamlClass configurations
# ###############################################################################
# 
# # trailing comment
# trailing: trailing value
# 
# # leading comment
# leading: leading value
# 
# # Line one of a long multiline leading comment
# # Line two of a long multiline leading comment
# # Line three of a long multiline leading comment
# long_leading: long_leading value
# 
# # leading of leading_and_trailing comment
# # trailing of leading_and_trailing comment
# leading_and_trailing: leading_and_trailing value
# 
# no_comment: no_comment value
# #nil_config: 
# }
#     
#     assert_equal expected[1..-1], cc.format_yaml
#     
#     expected_without_doc = %Q{
# ###############################################################################
# # FormatYamlClass configurations
# ###############################################################################
# trailing: trailing value
# leading: leading value
# long_leading: long_leading value
# leading_and_trailing: leading_and_trailing value
# no_comment: no_comment value
# #nil_config: 
# }
#     assert_equal expected_without_doc[1..-1], cc.format_yaml(false)
#     
#     cc = FormatYamlSubClass.configurations
#     assert ClassConfiguration, cc.class
#     
#     expected = %Q{
# ###############################################################################
# # FormatYamlClass configurations
# ###############################################################################
# 
# # trailing comment
# trailing: new trailing value
# 
# # leading comment
# leading: leading value
# 
# # Line one of a long multiline leading comment
# # Line two of a long multiline leading comment
# # Line three of a long multiline leading comment
# long_leading: long_leading value
# 
# # leading of leading_and_trailing comment
# # trailing of leading_and_trailing comment
# leading_and_trailing: leading_and_trailing value
# 
# #no_comment: 
# nil_config: no longer nil value
# 
# ###############################################################################
# # FormatYamlSubClass configuration
# ###############################################################################
# 
# # subclass_config comment
# subclass_config: subclass_config value
# 
# }
# 
#     assert_equal expected[1..-1], cc.format_yaml
# 
#     expected_without_doc = %Q{
# ###############################################################################
# # FormatYamlClass configurations
# ###############################################################################
# trailing: new trailing value
# leading: leading value
# long_leading: long_leading value
# leading_and_trailing: leading_and_trailing value
# #no_comment: 
# nil_config: no longer nil value
# 
# ###############################################################################
# # FormatYamlSubClass configuration
# ###############################################################################
# subclass_config: subclass_config value
# }
#     assert_equal expected_without_doc[1..-1], cc.format_yaml(false)
#   end

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
  
  # class AnotherClass
  # end
  
  # def test_add
  #   cc = ClassConfiguration.new
  #   cc.add(:key, 'value', ClassConfigurationTest)
  #   
  #   assert_equal [[:key, 'value', ClassConfigurationTest]], cc.declarations
  #   assert_equal({:key => 'value'}, cc.hash)
  #   
  #   cc.add(:key, 'new value', AnotherClass)  
  #   assert_equal [
  #     [:key, 'value', ClassConfigurationTest], 
  #     [:key, 'new value', AnotherClass]
  #   ], cc.declarations
  #   assert_equal({:key => 'new value'}, cc.hash)
  # end
  # 
  # def test_add_symbolizes_keys
  #   cc = ClassConfiguration.new
  #   cc.add('key', 'value', ClassConfigurationTest)
  #   
  #   assert_equal [[:key, 'value', ClassConfigurationTest]], cc.declarations
  #   assert_equal({:key => 'value'}, cc.hash)
  # end

  # def test_add_raises_error_if_declarations_are_not_correct
  #   cc = ClassConfiguration.new
  #   assert_raise(ArgumentError) { cc.add(:key, 'value')}
  #   assert_raise(ArgumentError) { cc.add([:key, 'value'])}
  # end

  #
  # remove configurations
  #
  
  # def test_remove
  #   cc = ClassConfiguration.new(
  #     [:one, 1, ClassConfigurationTest],
  #     [:one, 'one', AnotherClass],
  #     [:two, 'two', AnotherClass],
  #     [:three, 'three', AnotherClass])
  #   
  #   assert_equal 4, cc.declarations.length
  #   assert_equal({:one => 'one', :two => 'two', :three => 'three'}, cc.hash)
  #   
  #   cc.remove(:one, :three)
  #   assert_equal [[:two, 'two', AnotherClass]], cc.declarations  
  #   assert_equal({:two => 'two'}, cc.hash)
  # end
  # 
  # def test_remove_symbolizes_inputs
  #   cc = ClassConfiguration.new([:key, 'value', ClassConfigurationTest])
  #   cc.remove('key')
  #   assert_equal [], cc.declarations
  # end

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