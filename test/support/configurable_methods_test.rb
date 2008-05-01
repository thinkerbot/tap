require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/configurable_methods'

class ConfigurableMethodsTest < Test::Unit::TestCase
  
  #
  # documentation test
  #

  class ConfigurableClass
    extend Tap::Support::ConfigurableMethods

    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end
  
  def test_documentation
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, ConfigurableClass.configurations.default)
  end
  
  #
  # extend test
  #
  
  class IncludeClass
    extend Tap::Support::ConfigurableMethods
  end
  
  def test_extend_initializes_class_configurations
    assert_equal Tap::Support::ClassConfiguration, IncludeClass.configurations.class
    assert_equal IncludeClass, IncludeClass.configurations.receiver
  end
  
  #
  # inheritance test
  #
  
  # class IncludeBase
  #   extend Tap::Support::ConfigurableMethods
  # end
  # 
  # class IncludeSubclass < IncludeBase 
  # end
  # 
  # def test_subclassing_passes_on_configurations
  #   assert_equal Tap::Support::ClassConfiguration, IncludeModule.configurations.class
  #   assert_equal IncludeModule, IncludeModule.configurations.receiver
  # end
  
  #
  # default_name test
  #
  
  class NameClass
    extend Tap::Support::ConfigurableMethods
    class NestedClass
      extend Tap::Support::ConfigurableMethods
    end
  end
  
  def test_default_name_is_underscored_class_name
    assert_equal "configurable_methods_test/name_class", NameClass.default_name
    assert_equal "configurable_methods_test/name_class/nested_class", NameClass::NestedClass.default_name
  end
  
  #
  # config tests
  #
  # 
  # class SampleClass
  #   extend Tap::Support::ConfigurableMethods
  #   
  #   config :key, 'value'
  #   config_reader
  #   config :reader_only
  # end
  # 
  # class ValidatingClass
  #   extend Tap::Support::ConfigurableMethods
  # 
  #   config :one, 'one', &c.check(String)
  #   config :two, 'two' do |v| 
  #     v.upcase
  #   end
  # end
  # 
  # # def test_config_doc
  # #   t = SampleClass.new
  # #   assert t.respond_to?(:reader_only)
  # #   assert !t.respond_to?(:reader_only=)
  # # 
  # #   assert_equal({:key => 'value', :reader_only => nil}, t.config)
  # #   assert_equal 'value', t.key  
  # #   t.key = 'another'
  # #   assert_equal({:key => 'another', :reader_only => nil}, t.config)
  # #   
  # #   t = ValidatingClass.new
  # #   assert_equal({:one => 'one', :two => 'TWO'}, t.config)
  # #   assert_raise(Tap::Support::Validation::ValidationError) { t.one = 1 }
  # #   assert_raise(Tap::Support::Validation::ValidationError) { t.config = {:one => 1} }
  # #   
  # #   t.config = {:one => 'str', :two => 'str'}
  # #   assert_equal({:one => 'str', :two => 'STR'}, t.config)
  # # end
  # 
  # # def test_config_sets_config
  # #   t = ConfigurableClassWithNoConfigs.new
  # #   assert_equal({}, t.config)
  # #   t.config = {:key => 'value'}
  # #   assert_equal({:key => 'value'}, t.config)
  # # end
  # 
  # # def test_config_merges_default_config_and_overrides
  # #   t = ConfigurableClass.new "configured"
  # #   assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.class.configurations.default)
  # #   assert_equal({:one => 'one', :two => 'TWO', :three => 'THREE'}, t.config)
  # #   
  # #   t.config = {:three => 3}
  # #   assert_equal({:one => 'one', :two => 'two', :three => 3}, t.config)
  # # end
  # 
  # class ConfigurableClassWithManyConfigs
  #   include Tap::Support::Configurable
  #   
  #   config :one, 'one'
  #   
  #   declare_config
  #   config :two, 'two'
  #   
  #   config_reader
  #   config :three, 'three'
  #   
  #   config_writer
  #   config :four, 'four'
  #   
  #   config_accessor
  #   config :five, 'five'
  #   
  #   declare_config :six
  #   config_reader :seven
  #   config_writer :eight
  #   config_accessor :nine
  # end
  # 
  # def test_config_with_many_configs
  #   t = ConfigurableClassWithManyConfigs.new
  #   
  #   assert_equal({
  #     :one => 'one',     :six => nil, 
  #     :two => 'two',     :seven => nil,
  #     :three => 'three', :eight => nil,
  #     :four => 'four',   :nine => nil,
  #     :five => 'five'},
  #   t.config)
  #   
  #   # readers only
  #   [:three, :seven].each do |config|
  #     assert t.respond_to?(config)
  #     assert !t.respond_to?("#{config}=")
  #   end
  #   
  #   # writers only
  #   [:four, :eight].each do |config|
  #     assert !t.respond_to?(config)
  #     assert t.respond_to?("#{config}=")
  #   end
  # 
  #   # both
  #   [:one, :five, :nine].each do |config|
  #     assert t.respond_to?(config)
  #     assert t.respond_to?("#{config}=")
  #   end
  #   
  #   # neither
  #   [:two, :six].each do |config|
  #     assert !t.respond_to?(config)
  #     assert !t.respond_to?("#{config}=")
  #   end
  # end
  
  
end
