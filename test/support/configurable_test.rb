require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/class_configuration'
require 'tap/support/validation'
require 'tap/support/configurable_methods'
require 'tap/support/tdoc'
require 'tap/support/configurable'

# for documentation test
# class BaseTask 
#   include Tap::Support::Configurable
#   config :one, 1
# end
# class SubTask < BaseTask
#   config :one, 'one'
#   config :two, 'two'
# end
# 

class ConfigurableTest < Test::Unit::TestCase
  acts_as_tap_test

  class ConfigurableClassWithNoConfigs
    include Tap::Support::Configurable
  end
  
  class ConfigurableClass
    include Tap::Support::Configurable
    
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end

  def setup
    super
    app.root = trs.root
  end
  
  def test_configurable_doc
    t = ConfigurableClass.new 
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.config)
  end
  
  #
  # include test
  #
  
  def test_include_extends_class_with_ConfigurableMethods
    assert ConfigurableClassWithNoConfigs.kind_of?(Tap::Support::ConfigurableMethods)
  end
  
  #
  # default_name test
  #
  
  def test_default_name
    assert_equal "configurable_test/configurable_class", ConfigurableClass.default_name
  end
  
  #
  # name test
  #
  
  def test_name_is_initialized_to_class_default_name_unless_specified
    assert_equal ConfigurableClass.default_name, ConfigurableClass.new.name
    assert_equal "alt", ConfigurableClass.new("alt").name
  end

  # config_file test
  #
  
  def test_config_file_is_app_config_filepath_when_config_file_exist
    t = ConfigurableClass.new "configured"
    app_config_filepath = app.config_filepath("configured")
    
    assert_equal File.join(t.app['config'], "configured.yml"),app_config_filepath
    assert File.exists?(app_config_filepath)
    assert_equal app.config_filepath("configured"), t.config_file
  end

  def test_config_file_is_nil_for_nil_input_names
    t = ConfigurableClass.new 
    assert_equal nil, t.config_file
    
    t = ConfigurableClass.new nil
    assert_equal nil, t.config_file
  end
  
  #
  # config tests
  #
  
  class SampleClass
    include Tap::Support::Configurable
    
    config :key, 'value'
    config_reader
    config :reader_only
  end
  
  class ValidatingClass
    include Tap::Support::Configurable

    config :one, 'one', &c.check(String)
    config :two, 'two' do |v| 
      v.upcase
    end
  end
  
  def test_config_doc
    t = SampleClass.new
    assert t.respond_to?(:reader_only)
    assert !t.respond_to?(:reader_only=)
  
    assert_equal({:key => 'value', :reader_only => nil}, t.config)
    assert_equal 'value', t.key  
    t.key = 'another'
    assert_equal({:key => 'another', :reader_only => nil}, t.config)
    
    t = ValidatingClass.new
    assert_equal({:one => 'one', :two => 'TWO'}, t.config)
    assert_raise(Tap::Support::Validation::ValidationError) { t.one = 1 }
    assert_raise(Tap::Support::Validation::ValidationError) { t.config = {:one => 1} }
    
    t.config = {:one => 'str', :two => 'str'}
    assert_equal({:one => 'str', :two => 'STR'}, t.config)
  end
  
  def test_config_sets_config
    t = ConfigurableClassWithNoConfigs.new
    assert_equal({}, t.config)
    t.config = {:key => 'value'}
    assert_equal({:key => 'value'}, t.config)
  end
  
  def test_config_merges_default_config_and_overrides
    t = ConfigurableClass.new "configured"
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.class.configurations.default)
    assert_equal({:one => 'one', :two => 'TWO', :three => 'THREE'}, t.config)
    
    t.config = {:three => 3}
    assert_equal({:one => 'one', :two => 'two', :three => 3}, t.config)
  end
  
  class ConfigurableClassWithManyConfigs
    include Tap::Support::Configurable
    
    config :one, 'one'
    
    declare_config
    config :two, 'two'
    
    config_reader
    config :three, 'three'
    
    config_writer
    config :four, 'four'
    
    config_accessor
    config :five, 'five'
    
    declare_config :six
    config_reader :seven
    config_writer :eight
    config_accessor :nine
  end
  
  def test_config_with_many_configs
    t = ConfigurableClassWithManyConfigs.new
    
    assert_equal({
      :one => 'one',     :six => nil, 
      :two => 'two',     :seven => nil,
      :three => 'three', :eight => nil,
      :four => 'four',   :nine => nil,
      :five => 'five'},
    t.config)
    
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
    [:one, :five, :nine].each do |config|
      assert t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
    
    # neither
    [:two, :six].each do |config|
      assert !t.respond_to?(config)
      assert !t.respond_to?("#{config}=")
    end
  end

  #
  # test subclass behavior
  #
  
  class DeclarationClass
    include Tap::Support::Configurable
    
    declare_config

    config :one, 1
    config :two, 2
    config :three, 3

    config_accessor :one
    config_writer :two
    config_reader :three
  end
  
  class DeclarationSubClass < DeclarationClass
    config :one, "one"
    config :four, 4
  end
  
  def test_config_accessors_are_inherited
    t = DeclarationSubClass.new
    
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
    assert !t.respond_to?(:two)
    assert t.respond_to?("two=")
    assert t.respond_to?(:three)
    assert !t.respond_to?("three=")
    
    assert t.respond_to?(:four)
    assert t.respond_to?("four=")
  end
  
  def test_class_configurations_are_inherited_but_can_be_overridden
    assert_equal([
      [DeclarationClass, [:one, :two, :three]],
      [DeclarationSubClass, [:four]]
    ], DeclarationSubClass.configurations.declarations_array)
    
    assert_equal({:one => 1, :two => 2, :three => 3}, DeclarationClass.configurations.default)
    assert_equal({:one => 'one', :two => 2, :three => 3, :four => 4}, DeclarationSubClass.configurations.default)
    
    t = DeclarationSubClass.new
    assert_equal({:one => 'one', :two => 2, :three => 3, :four => 4}, t.config)
  end
  
  #
  # initialize_batch_obj test
  #
  
  def test_initialize_batch_obj_merges_default_config_and_overrides
    t = ConfigurableClass.new "configured", :three => 3
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t.class.configurations.default)
    assert_equal({:one => 'one', :two => 'TWO', :three => 3}, t.config)
    
    t1 = t.initialize_batch_obj
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t1.config)  
    
    t2 = t.initialize_batch_obj(nil, {:three => 3})
    assert_equal({:one => 'one', :two => 'two', :three => 3}, t2.config)
  end
  
  
  # include Tap::Support
  # 
  # def test_config_validations
  #   t = ValidationTask.new
  #   assert_equal({:one => 'one', :two => 'two', :three => 'THREE'}, t.config)
  #   
  #   t.one = 'two'
  #   assert_equal 'two', t.one  
  #   assert_raise(Validation::ValidationError) { t.one = 1 }
  #   
  #   t.two = "two"
  #   assert_equal 'two', t.two
  #   t.two = 2
  #   assert_equal 2, t.two    
  #   t.two = "2"
  #   assert_equal 2, t.two
  #   assert_raise(Validation::ValidationError) { t.two = 'three' }
  #   assert_raise(Validation::ValidationError) { t.two = 2.2 }
  #   
  #   t.three = "three"
  #   assert_equal 'THREE', t.three
  #   assert_raise(RuntimeError) { t.three = 'THREE' } 
  # end

end
