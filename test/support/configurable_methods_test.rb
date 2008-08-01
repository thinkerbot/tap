require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurableMethodsTest < Test::Unit::TestCase
  include Tap::Support 
  
  #
  # documentation test
  #

  class ConfigurableClass
    extend Tap::Support::ConfigurableMethods
    config :one, 'one'
  end

  class AnotherConfigurableClass
    extend Tap::Support::ConfigurableMethods
    config(:one, 'one') {|value| value.upcase }
  end

  class YetAnotherConfigurableClass
    extend Tap::Support::ConfigurableMethods
    config_attr(:one, 'one') {|value| @one = value.reverse }
  end

  def test_documentation
    assert_equal({:one => 'one'}, ConfigurableClass.configurations.to_hash)
    
    c = ConfigurableClass.new
    assert c.respond_to?('one')
    assert c.respond_to?('one=')
  
    ac = AnotherConfigurableClass.new
    ac.one = 'value'
    
    ac = YetAnotherConfigurableClass.new
    ac.one = 'value'
    assert_equal 'eulav', ac.one
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
    assert_equal({:one => Configuration.new(:one, 'one')}, IncludeSubclass.configurations.map)
  end
  
  def test_subclassing_passes_on_accessors
    t = IncludeSubclass.new
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
  end
  
  def test_inherited_configurations_can_be_overridden
    assert_equal({:one => Configuration.new(:one, 'one')}, IncludeBase.configurations.map)
    assert_equal({:one => Configuration.new(:one, 'ONE')}, OverrideSubclass.configurations.map)
  end
  
  #
  # config declaration tests
  #

  class SampleClass
    extend Tap::Support::ConfigurableMethods
    
    def initialize
      @zero = @one = @two = @three = nil
    end
    config_attr :zero, 'zero' do |value|
      @zero = value.upcase
      nil
    end
    
    config :one, 'one' do |value|
      value.upcase
    end
    
    config :two, 'two'
    config :three
  end
  
  def test_config_sets_class_configuration
    assert_equal({
      :zero => Configuration.new(:zero, 'zero'),
      :one => Configuration.new(:one, 'one'),
      :two => Configuration.new(:two, 'two'),
      :three => Configuration.new(:three)
    },
    SampleClass.configurations.map)
  end
  
  def test_config_generates_accessors
    t = SampleClass.new
    
    # both
    [:zero, :one, :two, :three].each do |config|
      assert t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
  end
  
  def test_config_reader_targets_instance_variable
    t = SampleClass.new
    assert_nil t.three
    t.instance_variable_set(:@three, 'three')
    assert_equal 'three', t.three
  end
  
  def test_config_writer_targets_instance_variable
    t = SampleClass.new
    assert_nil t.instance_variable_get(:@three)
    t.three = 'three'
    assert_equal 'three', t.instance_variable_get(:@three)
  end
  
  def test_config_attr_with_block_uses_block_as_writer_method_body
    t = SampleClass.new
    
    assert_nil t.zero
    t.zero = 'zero'
    
    assert_equal 'ZERO', t.zero
    assert_equal 'ZERO', t.instance_variable_get(:@zero)
  end
  
  def test_config_with_block_uses_block_return_to_set_instance_variable
    t = SampleClass.new
    
    assert_nil t.one
    t.one = 'one'
    
    assert_equal 'ONE', t.one
    assert_equal 'ONE', t.instance_variable_get(:@one)
  end
  
  #
  # config_attr test
  #
  
  class DocSampleClass
    include Tap::Support::Configurable

    def initialize
      initialize_config
    end
    
    config_attr :str, 'value'
    config_attr(:upcase, 'value') {|input| @upcase = input.upcase } 
  end

  class DocAlternativeClass
    include Tap::Support::Configurable

    config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym

    def initialize
      initialize_config
    end
    
    def get_sym
      @sym
    end

    def set_sym(input)
      @sym = input.to_sym
    end
  end

  def test_config_attr_documentation
    s = DocSampleClass.new
    assert_equal Tap::Support::InstanceConfiguration, s.config.class
    assert_equal 'value', s.str
    assert_equal 'value', s.config[:str]
  
    s.str = 'one'
    assert_equal 'one', s.config[:str]
    
    s.config[:str] = 'two' 
    assert_equal 'two', s.str
    
    ###
    alt = DocAlternativeClass.new
    assert_equal false, alt.respond_to?(:sym)
    assert_equal false, alt.respond_to?(:sym=)
    
    alt.config[:sym] = 'one'
    assert_equal :one, alt.get_sym
  
    alt.set_sym('two')
    assert_equal :two, alt.config[:sym]
  end
  
  #
  # context test
  #
  
  class ContextCheck
    extend Tap::Support::ConfigurableMethods
    
    class << self
      def context
        "Class"
      end
    end

    config :config_context do |value|
      context
    end
    
    config_attr :config_attr_context do |value|
      @config_attr_context = context
    end

    def context
      "Instance"
    end
  end
  
  def test_config_block_context_is_class
    c = ContextCheck.new
    c.config_context = nil
    assert_equal "Class", c.config_context
  end
  
  def test_config_attr_block_context_is_instance
    c = ContextCheck.new
    c.config_attr_context = nil
    assert_equal "Instance", c.config_attr_context 
  end
end
