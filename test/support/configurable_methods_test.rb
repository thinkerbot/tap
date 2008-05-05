require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurableMethodsTest < Test::Unit::TestCase
  
  ECHO_BLOCK = lambda {|value| value }
  
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
  
  class IncludeBase
    extend Tap::Support::ConfigurableMethods
    config :one, 'one'
  end
  
  class IncludeSubclass < IncludeBase 
  end
  
  class OverrideSubclass < IncludeBase 
     config(:one, 'ONE') 
  end
  
  def test_subclassing_passes_on_configurations
    assert_equal Tap::Support::ClassConfiguration, IncludeSubclass.configurations.class
    assert_equal IncludeSubclass, IncludeSubclass.configurations.receiver
    assert_equal({:one => 'one'}, IncludeSubclass.configurations.default)
  end
  
  def test_subclassing_passes_on_accessors
    t = IncludeSubclass.new
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
  end
  
  def test_inherited_configurations_can_be_overridden
    assert_equal({:one => 'one'}, IncludeBase.configurations.default)
    assert_equal({:one => 'ONE'}, OverrideSubclass.configurations.default)
  end
  
  #
  # config declaration tests
  #
  
  class DocSampleClass
    extend Tap::Support::ConfigurableMethods

    config :key, 'value'

    config_reader
    config :reader_only
  end
  
  def test_config_documentation
    t = DocSampleClass.new
    assert t.respond_to?(:reader_only)
    assert !t.respond_to?(:reader_only=)
  end
  
  class SampleClass
    extend Tap::Support::ConfigurableMethods
    
    config :one, 'one', &ECHO_BLOCK
    
    declare_config
    config :two, 'two', &ECHO_BLOCK
    
    config_reader
    config :three, 'three'
    
    config_writer
    config :four, 'four'
    
    config_accessor
    config :five, 'five'
    
    declare_config :six
    config_reader :seven
    config_writer :eight
    config_accessor :nine, :ten
    
    # stub methods implementing accessors
    attr_accessor :config
    def initialize() @config = {}; end
    def get_config(key) config[key]; end
    def set_config(key, value) config[key] = value; end
  end
  
  def test_config_sets_class_configuration
    assert_equal({
      :one => 'one',     :six => nil, 
      :two => 'two',     :seven => nil,
      :three => 'three', :eight => nil,
      :four => 'four',   :nine => nil,
      :five => 'five',   :ten => nil},
    SampleClass.configurations.default)
    
    assert_equal(
    {:one => ECHO_BLOCK, :two => ECHO_BLOCK},
    SampleClass.configurations.process_blocks)
  end
  
  def test_config_declarations
    t = SampleClass.new
    
    # readers only
    [:three, :seven].each do |config|
      assert t.respond_to?(config)
      assert !t.respond_to?("#{config}=")
    end
    
    # writers only
    [:four, :eight].each do |config|
      assert !t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
  
    # both
    [:one, :five, :nine, :ten].each do |config|
      assert t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
    
    # neither
    [:two, :six].each do |config|
      assert !t.respond_to?(config)
      assert !t.respond_to?("#{config}=")
    end
  end
  
  def test_config_accessors_access_configs_through_get_set_config
    t = SampleClass.new
    t.config = {:three => 'three', :eight => 'eight', :nine => 'nine'}
    
    # reader
    assert_equal 'three', t.config[:three]
    assert_equal 'three', t.three
    
    # writer
    assert_equal 'eight', t.config[:eight]
    t.eight = "EIGHT"
    assert_equal 'EIGHT', t.config[:eight]
    
    # accessor
    assert_equal 'nine', t.config[:nine]
    assert_equal 'nine', t.nine
    
    t.nine = "NINE"
    
    assert_equal 'NINE', t.config[:nine]
    assert_equal 'NINE', t.nine
  end
  
  #
  # config_merge test
  #
  
  class BaseClass
    extend Tap::Support::ConfigurableMethods
    config :one, 'one'
  end
  
  class SubClassOne < BaseClass
    config :two, 'two', &ECHO_BLOCK
  end
  
  class SubClassTwo < BaseClass
    config_merge SubClassOne
    config :three, 'three'
  end
  
  class AltBaseClass
    extend Tap::Support::ConfigurableMethods
    config_writer
    config_merge SubClassOne
  end
  
  def test_config_merge_merges_configs_from_another_class
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, SubClassTwo.configurations.default)
    assert_equal({:two => ECHO_BLOCK}, SubClassTwo.configurations.process_blocks)
  end
  
  def test_config_merge_creates_accessors_in_current_mode
    t = SubClassTwo.new
    assert t.respond_to?('one')
    assert t.respond_to?('one=')
    assert t.respond_to?('two')
    assert t.respond_to?('two=')
    
    t = AltBaseClass.new
    assert !t.respond_to?('one')
    assert t.respond_to?('one=')
    assert !t.respond_to?('two')
    assert t.respond_to?('two=')
  end
  
  def test_config_merge_raises_error_if_class_cannot_be_merged
    klass = Class.new
    klass.extend Tap::Support::ConfigurableMethods
    klass.config :one
    
    assert_raise(ArgumentError) { klass.config_merge BaseClass }
  end
end
