require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/task'
require 'tap/test'

# used in documentation test
class ConfiguredTask < Tap::Task
  config :one, 'one'
  config :two, 'two'
end

class ValidatingTask < Tap::Task
  config :string, 'str', &c.check(String)
  config :integer, 1, &c.yaml(Integer)
end 

class SubclassTask < Tap::Task
  attr_accessor :array
  def initialize(*args)
    @array = []
    super
  end

  def initialize_copy(orig)
    @array = orig.array.dup
    super
  end
end

class TaskTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Task = Tap::Task
  
  attr_accessor :t
  
  def setup
    super
    @t = Task.new
  end
  
  # sample class repeatedly used in tests
  class Sample < Tap::Task
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end
  
  #
  # documentation test
  #
  
  def test_documentation
    ####
    t = ConfiguredTask.new
    assert_equal({:one => 'one', :two => 'two'}, t.config)
    assert_equal('one', t.one)
    t.one = 'ONE'
    assert_equal({:one => 'ONE', :two => 'two'}, t.config)
  
    t = ConfiguredTask.new(:one => 'ONE', :three => 'three')
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, t.config)
    assert_equal false, t.respond_to?(:three)
  
    ####
    t = ValidatingTask.new
    assert_raises(Configurable::Validation::ValidationError) { t.string = 1 }
    assert_raises(Configurable::Validation::ValidationError) { t.integer = 1.1 }
  
    t.integer = "1"
    assert t.integer == 1
  end
  
  #
  # Task.parse test
  #
  
  def prepare_yaml(path, obj)
    method_root.prepare(path) {|file| file << YAML.dump(obj) }
  end
  
  def test_parse_returns_instance
    instance = Task.parse([])
    assert_equal Task, instance.class
  end
  
  class ParseClass < Tap::Task
    config :key, 'value'
  end
  
  def test_parse_returns_instance_of_subclass
    instance = ParseClass.parse([])
    assert_equal ParseClass, instance.class
  end
  
  def test_parse_instance_is_initialized_with_default_config
    instance = ParseClass.parse([])
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_parse_reconfigures_instance_using_configs_in_argv
    instance = ParseClass.parse(%w{--key alt})
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_adds_configs_from_file_using_config_option
    path = prepare_yaml('config.yml', {:key => 'alt'})
    
    instance = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_config_files_may_have_string_keys
    path = prepare_yaml('config.yml', {'key' => 'alt'})
    
    instance = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_recursively_loads_config_files
    path = prepare_yaml("a.yml", {'a' => 'A'})
           prepare_yaml("a/b.yml", 'B')
           prepare_yaml("a/c.yml", 'C')

    instance = Task.parse(["--config", path])
    assert_equal({
      'a' => 'A', 
      'b' => 'B', 
      'c' => 'C'
    }, instance.config.to_hash)
  end
  
  def test_parse_raises_error_for_non_existant_config_file
    path = method_root.path('config.yml')
    assert_equal false, File.exists?(path)

    err = assert_raises(Errno::ENOENT) { ParseClass.parse ["--config", path] }
    assert_equal "No such file or directory - #{path}", err.message
  end
  
  def test_parse_raises_error_for_ambiguity_in_configs
    path = method_root.prepare('config.yml') do |file| 
      file << {'key' => 'one'}.to_yaml
    end
    
    err = assert_raises(RuntimeError) { ParseClass.parse ["--key", "two", "--config", path] }
    assert_equal "multiple values map to config: :key", err.message
    
    err = assert_raises(RuntimeError) { ParseClass.parse ["--config", path, "--key", "two"] }
    assert_equal "multiple values map to config: :key", err.message
  end
  
  def test_parse_uses_ARGV_if_unspecified
    current_argv = ARGV.dup
    begin
      ARGV.clear
      ARGV.concat(%w{--key alt})
      
      instance = ParseClass.parse
      assert_equal({:key => 'alt'}, instance.config)
    ensure
      ARGV.clear
      ARGV.concat(current_argv)
    end
  end
  
  #
  # build test
  #
  
  class BuildClass < Tap::Task
    config :key, 'value'
  end
  
  def test_build_returns_instance_of_subclass
    instance = BuildClass.build
    assert_equal BuildClass, instance.class
  end
  
  def test_instance_is_built_with_default_config
    instance = BuildClass.build
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_instance_is_built_with_user_config
    instance = BuildClass.build 'config' => {:key => 'alt'}
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_build_respects_indifferent_access
    instance = BuildClass.build 'config' => {'key' => 'alt'}
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  #
  # initialization tests
  #
  
  def test_default_initialization
    assert_equal Tap::App.instance, t.app
    assert_equal({}, t.config)
  end
  
  def test_initialization_with_config
    t = Task.new({:key => 'value'})
    assert_equal({:key => 'value'}, t.config)
  end
  
  #
  # process test
  #
  
  def test_process_returns_inputs
    t = Task.new
    assert_equal [1,2,3], t.process(1,2,3)
  end

end