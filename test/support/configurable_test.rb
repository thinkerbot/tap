require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurableTest < Test::Unit::TestCase
   acts_as_tap_test

  # sample class repeatedly used in tests
  class Sample
    include Tap::Support::Configurable
    
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two'
  end
  
  def test_sample
    assert_equal({:one => 'one', :two => 'two'}, Sample.configurations.default)
    
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
      self.config = overrides
    end
  end
  
  class ValidatingClass < ConfigurableClass
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two', &c.check(String)
  end
  
  # def test_documentation
  #   c = ConfigurableClass.new
  #   assert_equal({:one => 'one', :two => 'two', :three => 'three'}, c.config)
  # 
  #   c.config[:one] = 'ONE'
  #   assert_equal 'ONE', c.one
  # 
  #   c.one = 1           
  #   assert_equal({:one => 1, :two => 'two', :three => 'three'}, c.config)
  # 
  #   v = ValidatingClass.new
  #   assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, v.config)
  #   v.one = 'aNothER'             
  #   assert_equal 'ANOTHER', v.one
  #   assert_raise(Tap::Support::Validation::ValidationError) { v.two = 2 }
  # end
  
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
    assert_equal({:one => 'ONE', :two => 2}, t.config.to_hash)
  end
  
  def test_config_sets_configs_through_accessors
    t = Sample.new
    t.config = {:one => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config.to_hash)
  end

  def test_config_symbolizes_input_keys
    t = Sample.new
    t.config = {'one' => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config.to_hash)
  end
  
  def test_config_is_detached_from_class_default
    t = Sample.new
    t.config = {'one' => 'Alt'}
    assert_equal({:one => 'ALT', :two => 'two'}, t.config.to_hash)
    assert_equal({:one => 'one', :two => 'two'}, Sample.configurations.default.to_hash)
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
    t.config = {}
    
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
