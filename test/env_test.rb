require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/env'
#require 'tap/support/dependencies'

class EnvTest < Test::Unit::TestCase
  
  acts_as_file_test
  
  attr_accessor :e, :root
  
  def setup
    super

    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @e = Tap::Env.new
    @root = Tap::Root.new
  end
  
  def teardown
    super
    
    Tap::Env.send(:class_variable_set, :@@instance, nil)
    $LOAD_PATH.clear
    $LOAD_PATH.concat(@current_load_paths)
  end
  
  class MockLogger < Array
    def add(*args)
      self << args
    end
  end
  
  #
  # reload test
  #
  
  # def test_reload_returns_unloaded_constants
  #   Dependencies.clear
  #   Dependencies.load_paths << method_root
  # 
  #   assert_equal [], e.reload
  #   assert File.exists?( File.join(method_root, 'env_test_class.rb') )
  #   
  #   assert !Object.const_defined?("EnvTestClass")
  #   klass = EnvTestClass
  #     
  #   assert Object.const_defined?("EnvTestClass")
  #   assert_equal [:EnvTestClass], e.reload.collect {|c| c.to_sym }
  #   assert !Object.const_defined?("EnvTestClass")
  # end
  
  
  #
  # read_config test 
  #
  
  def test_read_config_templates_then_loads_config
    config_file = method_tempfile
    
    File.open(config_file, "wb") {|f| f << "sum: <%= 1 + 2 %>" }
    assert_equal({'sum' => 3}, e.read_config(config_file))
  end
  
  def test_read_config_returns_empty_hash_for_non_existant_nil_and_false_files
    config_file = method_tempfile
    
    assert !File.exists?(config_file)
    assert_equal({}, e.read_config(config_file))
    
    FileUtils.touch(config_file)
    assert_equal({}, e.read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << nil.to_yaml }
    assert_equal(nil, YAML.load_file(config_file))
    assert_equal({}, e.read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << false.to_yaml }
    assert_equal(false, YAML.load_file(config_file))
    assert_equal({}, e.read_config(config_file))
  end
  
  def test_read_config_raises_error_for_non_hash_result
    config_file = method_tempfile
    
    File.open(config_file, "wb") {|f| f << [].to_yaml }
    assert_raise(RuntimeError) { e.read_config(config_file) }
    
    File.open(config_file, "wb") {|f| f << "just a string" }
    assert_raise(RuntimeError) { e.read_config(config_file) }
  end
  
  #
  # full_gem_path test
  #
  
  # def test_full_gem_path_returns_the_full_gem_path_for_the_specified_gem
  #   assert !Gem.loaded_specs.empty?
  #   gem_name, gem_spec = Gem.loaded_specs.to_a.first
  #   assert_equal gem_spec.full_gem_path, e.full_gem_path(gem_name)
  # end
  # 
  # def test_full_gem_path_accepts_versions
  #   assert !Gem.loaded_specs.empty?
  #   gem_name, gem_spec = Gem.loaded_specs.to_a.first
  #   assert_equal gem_spec.full_gem_path, e.full_gem_path(" #{gem_name} >= #{gem_spec.version} ")
  # end
   
  #
  # initialization tests
  #
  
  def test_env_is_configurable
    assert e.kind_of?(Tap::Support::Configurable)
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
  
  def test_load_path_targets_is_LOAD_PATH
    assert_equal [$LOAD_PATH], e.load_path_targets
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
    e.config.each_pair do |key, value|
      next unless value.kind_of?(Array)
      assert !value.frozen?
    end

    e.activate
    
    count = 0
    e.config.each_pair do |key, value|
      next unless value.kind_of?(Array)
      assert value.frozen?
      count += 1
    end
    
    assert count > 1
  end
  
  def test_activate_unshifts_load_paths_to_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear

    e.activate
    
    assert_equal ["/path/to/lib", "/path/to/another/lib"], $LOAD_PATH
  end
  
  def test_activate_prioritizes_load_paths_in_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["post", "/path/to/another/lib", "/path/to/lib"]
    
    e.activate
    
    assert_equal ["/path/to/lib", "/path/to/another/lib", "post"], $LOAD_PATH
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
    
    e.config.each_pair do |key, value|
      next unless value.kind_of?(Array)
      assert value.frozen?
    end
    
    e.deactivate
    
    count = 0
    e.config.each_pair do |key, value|
      next unless value.kind_of?(Array)
      assert !value.frozen?
      count += 1
    end
    
    assert count > 1
  end
  
  def test_deactivate_removes_load_paths_from_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    e.deactivate
    
    assert_equal ["pre", "post"], $LOAD_PATH
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
    assert_raise(RuntimeError) { e.debug = true }
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
    }, root)
  
    assert_equal [root['lib'], root['alt']], e.load_paths
    assert_equal [root['cmd']], e.command_paths
  end
  
  def test_configure_resolves_single_and_nil_values_for_PATH_CONFIGS_as_arrays
    e.configure({:load_paths => 'lib', :command_paths => nil}, root)
  
    assert_equal [root['lib']], e.load_paths
    assert_equal [], e.command_paths
  end
  
  def test_configure_adds_defaults_to_input
    e.configure({}, root)
    assert_equal [root['lib']], e.config[:load_paths]
  end
  
  def test_configure_reassigns_root_paths_using_configs_before_resolving_paths
    assert_not_equal 'alt', root['lib']
    e.configure({:load_paths => ['lib'], :directories => {'lib' => 'alt'}}, root)
    
    assert_not_equal 'alt', root['lib']
    assert_equal [root['alt']], e.load_paths
  end
  
  def test_configure_normalizes_keys
    e.configure({'load_paths' => ['lib'], 'directories' => {'lib' => 'alt'}}, root)
    assert_equal [root['alt']], e.load_paths
  end
  
  def test_uses_new_root_if_none_is_provided
    e.configure(:load_paths => ['lib'])
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
  
  def test_configure_will_only_set_RECURSIVE_CONFIGS_in_recursive_context
    assert !e.debug
    
    was_in_recursive_context = false
    e.recursive_context do
      e.configure({:debug => true}, root)
      was_in_recursive_context = true
    end
    
    assert !e.debug
    assert was_in_recursive_context
  end
  
  def test_configure_loads_config_path_configs_in_recursive_context
    config_file = method_tempfile
    File.open(config_file, "w") do |file| 
      file << {:load_paths => ['three'], :root => root.root}.to_yaml
    end
    
    e.configure({:load_paths => ['one', 'two'], :config_paths => [config_file]}, root)
    assert_equal [root['one'], root['two'], root['three']], e.load_paths
  end
  
  def test_recursive_loading_for_multiple_recursions
    config_file1 = method_tempfile
    config_file2 = method_tempfile
    config_file3 = method_tempfile
    
    File.open(config_file1, "w") do |file| 
      file << {:load_paths => ['one'], :config_paths => config_file2, :root => root.root}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:load_paths => ['two'], :config_paths => config_file3, :root => root.root}.to_yaml
    end
    
    File.open(config_file3, "w") do |file| 
      file << {:load_paths => ['three'], :root => root.root}.to_yaml
    end
    
    e.configure({:load_paths => ['zero'], :config_paths => config_file1}, root)
    assert_equal [root['zero'], root['one'], root['two'], root['three']], e.load_paths
  end
  
  def test_recursive_loading_does_not_infinitely_loop
    config_file1 = method_tempfile
    config_file2 = method_tempfile
    
    File.open(config_file1, "w") do |file| 
      file << {:load_paths => ['one'], :config_paths => config_file2, :root => root.root}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:load_paths => ['two'], :config_paths => config_file1, :root => root.root}.to_yaml
    end
    
    e.configure({:load_paths => ['zero'], :config_paths => config_file1}, root)
    assert_equal [root['zero'], root['one'], root['two']], e.load_paths
  end
  
  def test_recursive_loading_removes_duplicates_and_preserves_order_of_first_loading
    config_file1 = method_tempfile
    config_file2 = method_tempfile
    config_file3 = method_tempfile
    
    File.open(config_file1, "w") do |file| 
      file << {:load_paths => ['zero', 'one'], :config_paths => config_file2, :root => root.root}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:load_paths => ['one', 'zero', 'two'], :config_paths => config_file3, :root => root.root}.to_yaml
    end
    
    File.open(config_file3, "w") do |file| 
      file << {:load_paths => ['three', 'one', 'zero', 'two'], :root => root.root}.to_yaml
    end
    
    e.configure({:load_paths => ['zero'], :config_paths => config_file1}, root)
    assert_equal [root['zero'], root['one'], root['two'], root['three']], e.load_paths
  end
  
  #
  # load_config test
  #
  
  def test_load_config_configures_using_configs_from_file
    config_file = method_tempfile
    File.open(config_file, "w") do |file| 
      file << {:debug => true}.to_yaml
    end
    
    assert !e.debug
    e.load_config(config_file)
    assert e.debug
  end
  
  def test_loaded_config_files_are_added_to_config_paths
    config_file = method_tempfile
    e.load_config(config_file)
    assert e.config_paths.include?(config_file)
  end
  
  def test_load_config_reassigns_root_to_config_file_directory_unless_root_is_a_loaded_config
    config_file = method_tempfile
    File.open(config_file, "w") {|file| file << {:load_paths => ['lib']}.to_yaml }
    
    e.load_config(config_file)
    assert_equal [method_filepath(:output, 'lib')], e.load_paths
  end
  
  def test_config_file_for_load_config_does_not_need_to_exist
    config_file = method_tempfile
    assert_nothing_raised { e.load_config(config_file) }
  end
  
  def test_load_config_appends_DEFAULT_CONFIG_FILE_to_directory_configs_files
    dir = File.dirname(__FILE__)
    assert File.directory?(dir)
    e.load_config(dir)
    assert e.config_paths.include?( File.expand_path(File.join(dir, Tap::Env::DEFAULT_CONFIG_FILE)) )
  end
  
  #
  # recursive_context test
  #
  
  def test_in_recursive_context_is_true_if_in_recursive_context
    assert !e.in_recursive_context?
    
    e.recursive_context do
      assert e.in_recursive_context?
      
      e.recursive_context do
        assert e.in_recursive_context?
      end
      
      assert e.in_recursive_context?
    end
    
    assert !e.in_recursive_context?
  end
  
  #
  # commands test 
  #
  
  
  def test_commands_selects_commands_from_all_command_paths
    e.command_paths << method_dir(:one)
    e.command_paths << method_dir(:two)
    
    expected = {
      'cmd_one' => method_filepath(:one, 'cmd_one.rb'),
      'cmd_two' => method_filepath(:two, 'cmd_two.rb')
    }
    
    assert_equal expected, e.commands
  end
  
  def test_commands_selects_command_paths_in_reverse_order_of_command_path
    e.command_paths << method_dir(:one)
    e.command_paths << method_dir(:two)
    
    expected = {'cmd_two' => method_filepath(:one, 'cmd_two.rb')}
    
    assert_equal expected, e.commands
  end
end