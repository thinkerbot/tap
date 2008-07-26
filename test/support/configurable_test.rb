require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurableTest < Test::Unit::TestCase
   acts_as_tap_test
   include Tap::Support
   
  # sample class repeatedly used in tests
  class Sample
    include Tap::Support::Configurable
    
    def initialize
      initialize_config
    end
    
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two'
  end
  
  def test_sample
    assert_equal({
      :one => Configuration.new(:one, 'one'), 
      :two => Configuration.new(:two, 'two')
    }, Sample.configurations.map)
    
    s = Sample.new
    s.one = 'one'
    assert_equal 'ONE', s.one
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
      initialize_config overrides
    end
  end
  
  class ValidatingClass < ConfigurableClass
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two', &c.check(String)
  end
  
  def test_documentation
    c = ConfigurableClass.new
    assert_equal(Tap::Support::InstanceConfiguration, c.config.class)
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
  # config test 
  #
  
  def test_config_is_detached_from_class_default
    t = Sample.new
    t.config[:one] = 'Alt'
    
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
    assert_equal({
      :one => Configuration.new(:one, 'one'), 
      :two => Configuration.new(:two, 'two')
    }, Sample.configurations.map)
  end
  
  #
  # reconfigure test
  #
  
  def test_reconfigure_sets_configs_through_accessors
    t = Sample.new
    t.reconfigure(:one => 'Alt')
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
  end
  
  def test_reconfigure_symbolizes_input_keys
    t = Sample.new
    t.reconfigure('one' => 'Alt')
    assert_equal({:one => 'ALT', :two => 'two'}, t.config)
  end
  
  def test_reconfigure_only_affects_specified_keys
    t = Sample.new
    t.two = "TWO"
    t.reconfigure('one' => 'Alt')
    assert_equal({:one => 'ALT', :two => 'TWO'}, t.config)
  end
  
  def test_reconfigure_returns_self
    t = Sample.new
    assert_equal t, t.reconfigure
  end
  
  #
  # initialize_config test
  #
  
  def test_initialize_config_merges_class_defaults_with_overrides
    t = Sample.new
    t.send(:initialize_config, {:two => 2})
    assert_equal({:one => 'ONE', :two => 2}, t.config)
  end
  
  #
  # initialize_copy test
  #
  
  def test_dup_reinitializes_config
    t1 = Sample.new
    t2 = t1.dup
    
    assert_not_equal t1.config.object_id, t2.config.object_id
    
    t1.two = 2
    t2.two = 'two'
    assert_equal 2, t1.two
    assert_equal 'two', t2.two
  end

  #
  # benchmarks
  #
  
  class ConfigBenchmark
    include Tap::Support::Configurable
    
    config :config_key, nil
    config(:config_block, nil) {|value| value }
    attr_accessor :attr_key
  end
  
  def test_config_and_attr_speed
    t = ConfigBenchmark.new 
    t.send(:initialize_config)
    
    benchmark_test(20) do |x|
      n = 100000
      
      x.report("100k config_block= ") { n.times { t.config_block = 1 } }
      x.report("100k config= ") { n.times { t.config_key = 1 } }
      x.report("100k attr= ") { n.times { t.attr_key = 1 } }
      x.report("100k config[]= ") { n.times { t.config[:config_key] = 1 } }
      x.report("100k config[n]= ") { n.times { t.config[:key] = 1 } }
      
      x.report("100k config_block ") { n.times { t.config_block } }
      x.report("100k config ") { n.times { t.config_key } }
      x.report("100k attr ") { n.times { t.attr_key } }
      x.report("100k config[]") { n.times { t.config[:config_key] } }
      x.report("100k config[n] ") { n.times { t.config[:key] } }
      
    end
  end

end
