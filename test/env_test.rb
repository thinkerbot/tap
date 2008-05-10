require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/env'

class EnvTest < Test::Unit::TestCase
  
  acts_as_file_test
  
  attr_accessor :e
  
  def setup
    super
    
    @current_load_paths = $LOAD_PATH
    $LOAD_PATH.clear
    @current_dependencies_load_paths = Dependencies.load_paths
    Dependencies.load_paths.clear
    
    @e = Tap::Env.new
  end
  
  def teardown
    super
    
    Tap::Env.send(:class_variable_set, :@@instance, nil)
    $LOAD_PATH.clear
    $LOAD_PATH.concat(@current_load_paths)
    Dependencies.load_paths.clear
    Dependencies.load_paths.concat(@current_dependencies_load_paths)
  end
  
  class MockLogger < Array
    def add(*args)
      self << args
    end
  end
  
  #
  # Env.read_config test 
  #
  
  def test_read_config_templates_then_loads_config
    config_file = output_tempfile
    
    File.open(config_file, "wb") {|f| f << "sum: <%= 1 + 2 %>" }
    assert_equal({'sum' => 3}, Tap::Env.read_config(config_file))
  end
  
  def test_read_config_returns_empty_hash_for_non_existant_nil_and_false_files
    config_file = output_tempfile
    
    assert !File.exists?(config_file)
    assert_equal({}, Tap::Env.read_config(config_file))
    
    FileUtils.touch(config_file)
    assert_equal({}, Tap::Env.read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << nil.to_yaml }
    assert_equal(nil, YAML.load_file(config_file))
    assert_equal({}, Tap::Env.read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << false.to_yaml }
    assert_equal(false, YAML.load_file(config_file))
    assert_equal({}, Tap::Env.read_config(config_file))
  end
  
  def test_read_config_raises_error_for_non_hash_result
    config_file = output_tempfile
    
    File.open(config_file, "wb") {|f| f << [].to_yaml }
    assert_raise(RuntimeError) { Tap::Env.read_config(config_file) }
    
    File.open(config_file, "wb") {|f| f << "just a string" }
    assert_raise(RuntimeError) { Tap::Env.read_config(config_file) }
  end
  
  #
  # Env.full_gem_path test
  #
  
  def test_full_gem_path_returns_the_full_gem_path_for_the_specified_gem
    assert !Gem.loaded_specs.empty?
    gem_name, gem_spec = Gem.loaded_specs.to_a.first
    assert_equal gem_spec.full_gem_path, Tap::Env.full_gem_path(gem_name)
  end
  
  def test_full_gem_path_accepts_versions
    assert !Gem.loaded_specs.empty?
    gem_name, gem_spec = Gem.loaded_specs.to_a.first
    assert_equal gem_spec.full_gem_path, Tap::Env.full_gem_path(" #{gem_name} >= #{gem_spec.version} ")
  end
   
  #
  # initialization tests
  #
  
  def test_env_is_configurable
    assert e.kind_of?(Tap::Support::Configurable)
  end
  
  def test_class_default_config
    expected = {
      :load_paths => ['lib'],
      :config_paths => [],
      :command_paths => ['cmd'],
      :gems => [],
      :generator_paths => ['lib/generators'],
      :use_dependencies => true
    }
    
    assert_equal expected, Tap::Env.configurations.default
  end
  
  #
  # log test
  #
  
  def test_log_adds_message_to_logger_if_logger_is_set
    e.logger = MockLogger.new
    e.log :one, "message one", Logger::DEBUG
    e.log :two, "message two", Logger::INFO
    
    assert_equal [[Logger::DEBUG, "message one", "one"], [Logger::INFO, "message two", "two"]], e.logger
  end
  
  #
  # load_path_targets test
  #
  
  def test_load_path_targets_is_LOAD_PATH_if_not_using_dependencies
    e.use_dependencies = false
    assert_equal [$LOAD_PATH], e.load_path_targets
  end
  
  def test_load_path_targets_is_LOAD_PATH_and_Dependencies_load_paths_if_using_dependencies
    e.use_dependencies = true
    assert_equal [$LOAD_PATH, Dependencies.load_paths], e.load_path_targets
  end
  
  #
  # activate test
  #
  
  def test_activate_returns_false_if_active
    assert !e.active?
    assert e.activate
    
    assert e.active?
    assert !e.activate
  end

  def test_activate_freezes_array_configs
    assert !e.load_paths.frozen?
    assert !e.command_paths.frozen?
    
    e.activate
    
    assert e.load_paths.frozen?
    assert e.command_paths.frozen?
  end
  
  def test_activate_unshifts_load_paths_to_load_path_targets
    assert_equal [$LOAD_PATH, Dependencies.load_paths], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    Dependencies.load_paths.clear
    
    e.activate
    
    assert_equal ["/path/to/lib", "/path/to/another/lib"], $LOAD_PATH
    assert_equal ["/path/to/lib", "/path/to/another/lib"], Dependencies.load_paths
  end

  def test_activate_prioritizes_load_paths_in_load_path_targets
    assert_equal [$LOAD_PATH, Dependencies.load_paths], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["post", "/path/to/another/lib", "/path/to/lib"]
    
    Dependencies.load_paths.clear
    Dependencies.load_paths.concat ["post", "/path/to/another/lib", "/path/to/lib"]
    
    e.activate
    
    assert_equal ["/path/to/lib", "/path/to/another/lib", "post"], $LOAD_PATH
    assert_equal ["/path/to/lib", "/path/to/another/lib", "post"], Dependencies.load_paths
  end
  
  def test_activate_assigns_self_as_Env_instance
    assert_nil Tap::Env.instance
    e.activate
    assert_equal e, Tap::Env.instance
  end
  
  #
  # deactivate test
  #
  
  def test_deactivate_returns_false_unless_active
    assert !e.active?
    assert !e.deactivate
    
    e.activate
    
    assert e.active?
    assert e.deactivate
  end
  
  def test_deactivate_unfreezes_array_configs
    e.activate
    
    assert e.load_paths.frozen?
    assert e.command_paths.frozen?
    
    e.deactivate
    
    assert !e.load_paths.frozen?
    assert !e.command_paths.frozen?
  end

  def test_deactivate_removes_load_paths_from_load_path_targets
    assert_equal [$LOAD_PATH, Dependencies.load_paths], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    Dependencies.load_paths.clear
    Dependencies.load_paths.concat ["/path/to/lib", "/path/to/another/lib"]
    Dependencies.load_paths.unshift "pre"
    Dependencies.load_paths.push "post"
    
    e.deactivate
    
    assert_equal ["pre", "post"], $LOAD_PATH
    assert_equal ["pre", "post"], Dependencies.load_paths
  end
  
  def test_deactivate_does_not_remove_load_path_targets_unless_deactivated
    Tap::Env.send(:class_variable_set, :@@instance, Tap::Env.new)
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["/path/to/lib", "/path/to/another/lib"]
    
    assert !e.active?
    assert !e.deactivate
    assert_equal ["/path/to/lib", "/path/to/another/lib"], $LOAD_PATH
  end
  
  #
  # activate/deactivate test
  #
  
  def test_env_is_active_if_env_is_Env_instance
    assert !e.active?
    Tap::Env.send(:class_variable_set, :@@instance, e)
    assert e.active?
  end

  def test_activate_is_toggled_by_activate_and_deactivate
    e.activate
    assert e.active?
    
    e.deactivate
    assert !e.active?
  end

  def test_activate_deactivate_does_not_change_configs
    current_configs = e.config
    
    e.activate
    e.deactivate
    
    assert_equal current_configs, e.config
  end
  
  def test_config_modification_through_accessors_raise_error_when_active
    e.activate
    assert_raise(RuntimeError) { e.use_dependencies = true }
    assert_raise(RuntimeError) { e.load_paths = [] }
  end
  
  def test_activate_deactivates_Env_instance_if_necessary
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    assert e.activate
    assert_equal e, Tap::Env.instance
    
    alt = Tap::Env.new
    alt.load_paths = ["/alt/path/to/lib", "/alt/path/to/another/lib"]
    assert alt.activate
    assert_equal alt, Tap::Env.instance
    
    assert !e.active?
    assert alt.active?
    assert((e.load_paths & $LOAD_PATH).empty?)
    assert_equal $LOAD_PATH, alt.load_paths
  end
  
  #
  # configure test
  #
  
  def test_configure_returns_true
    assert_equal true, e.configure({})
  end
  
  def test_configure_resolves_PATH_CONFIGS_using_root
    e.configure({
      :load_paths => ['lib', 'alt'],
      :command_paths => ['cmd']
    }, trs)

    assert_equal [trs['lib'], trs['alt']], e.load_paths
    assert_equal [trs['cmd']], e.command_paths
  end
  
  def test_configure_resolves_single_and_nil_values_for_PATH_CONFIGS_as_arrays
    e.configure({:load_paths => 'lib', :command_paths => nil}, trs)

    assert_equal [trs['lib']], e.load_paths
    assert_equal [], e.command_paths
  end
  
  def test_configure_merges_default_with_inputs
    e.configure({:use_dependencies => false}, trs)

    expected = {
      :load_paths => [trs['lib']],
      :config_paths => [],
      :command_paths => [trs['cmd']],
      :gems => [],
      :generator_paths => [trs['lib/generators']],
      :use_dependencies => false
    }
    
    assert_equal expected, e.config
  end
  
  def test_configure_reassigns_root_paths_using_configs_before_resolving_paths
    assert_not_equal 'alt', trs['lib']
    e.configure({:load_paths => ['lib'], :directories => {'lib' => 'alt'}}, trs)
    
    assert_not_equal 'alt', trs['lib']
    assert_equal [trs['alt']], e.load_paths
  end
  
  def test_configure_normalizes_keys
    e.configure({'load_paths' => ['lib'], 'directories' => {'lib' => 'alt'}}, trs)
    assert_equal [trs['alt']], e.load_paths
  end
  
  def test_uses_new_root_if_none_is_provided
    e.configure(:load_paths => ['lib'])
    
    root = Tap::Root.new
    assert_equal [root['lib']], e.load_paths
  end
  
  def test_unused_configs_are_yielded_to_block
    was_in_block = false
    e.configure(:another => :value) do |other_configs|
      was_in_block = true
      assert_equal({:another => :value}, other_configs)
    end
    
    assert was_in_block
  end
  
  def test_configure_yields_to_block_even_if_no_other_configs_are_present
    was_in_block = false
    e.configure({}) do |other_configs|
      was_in_block = true
      assert_equal({}, other_configs)
    end
    
    assert was_in_block
  end
  
  def test_configure_logs_unused_configs_if_no_block_is_given
    e.logger = MockLogger.new
    e.configure(:unused => :value)
    
    assert_equal [[Logger::DEBUG, "ignoring non-env configs: unused", "warn"]], e.logger
  end
  

  
  #
  # load_config test
  #
  
  def test_load_config_configures_using_configs_from_file
    config_file = output_tempfile
    File.open(config_file, "w") {|file| file << {:use_dependencies => false}.to_yaml }
    
    assert e.use_dependencies
    e.load_config(config_file, trs)
    assert !e.use_dependencies
  end
  
  def test_loaded_config_files_are_added_to_config_paths
    config_file = output_tempfile
    e.load_config(config_file)
    assert e.config_paths.include?(config_file)
  end
  
  def test_load_config_reassigns_root_to_config_file_directory_unless_root_is_a_loaded_config
    config_file = output_tempfile
    File.open(config_file, "w") {|file| file << {:load_paths => ['lib']}.to_yaml }
    
    e.load_config(config_file)
    assert_equal [method_filepath(:output, 'lib')], e.load_paths
  end
  
  def test_config_file_for_load_config_does_not_need_to_exist
    config_file = output_tempfile
    assert_nothing_raised { e.load_config(config_file) }
  end
  


end