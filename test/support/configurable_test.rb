require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurableTest < Test::Unit::TestCase
  acts_as_tap_test

  # sample class repeatedly used in tests
  class Sample
    include Tap::Support::Configurable
    
    def initialize(config={})
      @config = config  
    end
    
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two'
  end
  
  def test_sample
    assert_equal({:one => 'ONE', :two => 'two'}, Sample.configurations.default)
  end
  
  #
  # documentation test
  #
  
  class ConfigurableClass
    include Tap::Support::Configurable

    config :one, 'one'
    config :two, 'two'
    config :three, 'three'

    def initialize(overrides={})
      self.config = overrides
    end
  end
  
  class ValidatingClass < ConfigurableClass
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two', &c.check(String)
  end
  
  def test_documentation
    c = ConfigurableClass.new
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, c.config)

    c.config[:one] = 'ONE'
    assert_equal 'ONE', c.one
  
    c.one = 1           
    assert_equal({:one => 1, :two => 'two', :three => 'three'}, c.config)
  
    v = ValidatingClass.new
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, v.config)
    v.one = 'aNothER'             
    assert_equal 'ANOTHER', v.one
    assert_raise(Tap::Support::Validation::ValidationError) { v.two = 2 }
  end
  
  #
  # include test
  #
  
  def test_include_extends_class_with_ConfigurableMethods
    assert Sample.kind_of?(Tap::Support::ConfigurableMethods)
  end
  
  #
  # class_configurations test
  #
  
  def test_class_configurations_returns_class_configurations
    assert_equal Sample.configurations, Sample.new.class_configurations
  end
  
  #
  # config= test
  #
  
  def test_config_merges_overrides_with_class_default_config
    t = Sample.new
    t.config = {:two => 2}
    assert_equal({:one => 'ONE', :two => 2}, t.config)
  end
  
  def test_config_processes_overrides_with_process_blocks
    t = Sample.new
    t.config = {:one => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
  end

  def test_config_normalizes_input_keys
    t = Sample.new
    t.config = {'one' => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
  end
  
  def test_config_is_detached_from_class_default
    t = Sample.new
    t.config = {'one' => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
    assert_equal({:one => 'ONE', :two => 'two'}, Sample.configurations.default)
  end
  
  #
  # set_config test
  #
  
  def test_set_config_normalizes_keys
    t = Sample.new
    assert_equal({}, t.config)
    
    t.send(:set_config, :one, "ONE")
    assert_equal({:one => 'ONE'}, t.config)
    
    t.send(:set_config, 'one', "ALT")
    assert_equal({:one => 'ALT'}, t.config)
  end
  
  def test_set_config_processes_values
    t = Sample.new
    t.send(:set_config, :one, "value")
    assert_equal({:one => 'VALUE'}, t.config)
  end
  
  #
  # get_config test
  #
  
  def test_get_config_normalizes_keys
    t = Sample.new :one => 'ONE'
    assert_equal "ONE", t.send(:get_config, :one)
    assert_equal "ONE", t.send(:get_config, 'one')
  end
  
end
