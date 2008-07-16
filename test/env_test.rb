require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/env'
#require 'tap/support/dependencies'

class EnvTest < Test::Unit::TestCase
  
  acts_as_file_test
  
  attr_accessor :e, :root
  
  def setup
    super
    
    @current_instance = Tap::Env.instance
    @current_instances = Tap::Env.instances.dup
    Tap::Env.send(:class_variable_set, :@@instances , {})
    Tap::Env.send(:class_variable_set, :@@instance, nil)
    
    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @root = Tap::Root.new
    @e = Tap::Env.new({}, root)
  end
  
  def teardown
    super
    
    Tap::Env.send(:class_variable_set, :@@instances , @current_instances)
    Tap::Env.send(:class_variable_set, :@@instance, @current_instance)
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
  # Env#read_config test 
  #
  
  def test_read_config_templates_then_loads_config
    config_file = method_tempfile
    
    File.open(config_file, "wb") {|f| f << "sum: <%= 1 + 2 %>" }
    assert_equal({'sum' => 3}, Tap::Env.read_config(config_file))
  end
  
  def test_read_config_returns_empty_hash_for_non_existant_nil_and_false_files
    config_file = method_tempfile
    
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
    config_file = method_tempfile
    
    File.open(config_file, "wb") {|f| f << [].to_yaml }
    assert_raise(RuntimeError) { Tap::Env.read_config(config_file) }
    
    File.open(config_file, "wb") {|f| f << "just a string" }
    assert_raise(RuntimeError) { Tap::Env.read_config(config_file) }
  end
  
  #
  # Env#full_gem_path test
  #
  
  # def test_full_gem_path_returns_the_full_gem_path_for_the_specified_gem
  #   assert !Gem.loaded_specs.empty?
  #   gem_name, gem_spec = Gem.loaded_specs.to_a.first
  #   assert_equal gem_spec.full_gem_path, Tap::Env.full_gem_path(gem_name)
  # end
  # 
  # def test_full_gem_path_accepts_versions
  #   assert !Gem.loaded_specs.empty?
  #   gem_name, gem_spec = Gem.loaded_specs.to_a.first
  #   assert_equal gem_spec.full_gem_path, Tap::Env.full_gem_path(" #{gem_name} >= #{gem_spec.version} ")
  # end
  
  #
  # static_config tests
  #
  
  class StaticConfigEnv < Tap::Env
    static_config(:test, 'test') {}
  end
  
  def test_set_static_config_raises_error_when_active
    e = StaticConfigEnv.new
    e.activate
    assert_raise(RuntimeError) { e.test = "value" }
  end
  
  def test_static_config_raises_error_when_no_block_is_given
    assert_nothing_raised { StaticConfigEnv.send(:static_config, :with_block, 'value') {} }
    assert_raise(ArgumentError) { StaticConfigEnv.send(:static_config, :without_block, 'value') }
  end
  
  #
  # path_config tests
  #
  
  class PathConfigEnv < Tap::Env
    path_config(:test_paths, ['test'])
  end
  
  def test_path_configs_are_resolved_using_root
    e = PathConfigEnv.new({:test_paths => ['dir', 'alt']}, root)
    assert_equal [root['dir'], root['alt']], e.test_paths
  end
  
  def test_path_configs_are_set_to_default_if_unspecified
    e = PathConfigEnv.new({}, root)
    assert_equal [root['test']], e.test_paths
  end
  
  def test_path_configs_resolves_single_values_as_arrays
    e = PathConfigEnv.new({:test_paths => 'dir'}, root)
    assert_equal [root['dir']], e.test_paths
  end
  
  def test_path_configs_ignore_nil_values
    e = PathConfigEnv.new({:test_paths => nil}, root)
    assert_equal [], e.test_paths
  end
  
  def test_set_path_config_raises_error_when_active
    e = PathConfigEnv.new
    e.activate
    assert_raise(RuntimeError) { e.test_paths = "value" }
  end
  
  #
  # manifest test
  #
  
  class ManifestEnv < Tap::Env
    path_config(:array_paths)
    manifest(:arrays, :array_paths) do |arrays, array_path|
      arrays << File.expand_path(array_path)
    end
    
    path_config(:hash_paths)
    manifest(:hashes, :hash_paths, true) do |hashes, hash_path|
      hash_path = File.expand_path(hash_path)
      hashes[File.basename(hash_path).chomp('.rb')] = hash_path
    end
  end
  
  def test_manifest_defines_protected_discover_manifest_method
    e = ManifestEnv.new
    assert e.respond_to?(:discover_arrays)
    assert ManifestEnv.protected_instance_methods.collect {|m| m.to_sym }.include?(:discover_arrays)
    
    assert e.respond_to?(:discover_hashes)
    assert ManifestEnv.protected_instance_methods.collect {|m| m.to_sym }.include?(:discover_hashes)
    
    arrays = []
    e.send(:discover_arrays, arrays, '/one')
    e.send(:discover_arrays, arrays, '/two')
    e.send(:discover_arrays, arrays, '/three')
    assert_equal([expand('/one'), expand('/two'), expand('/three')], arrays)
    
    hashes = {}
    e.send(:discover_hashes, hashes, '/one.rb')
    e.send(:discover_hashes, hashes, '/two.rb')
    e.send(:discover_hashes, hashes, '/three.rb')
    assert_equal({'one' => expand('/one.rb'), 'two' => expand('/two.rb'), 'three' => expand('/three.rb')}, hashes)
  end
  
  def test_manifest_method_visits_each_path_with_hash_or_array_as_specified_in_declaration
    e = ManifestEnv.new :array_paths => ['/one', '/two'], :hash_paths => ['/one.rb', '/two.rb']
    assert_equal([root['/one'], root['/two']], e.arrays)
    assert_equal({'one' => root['/one.rb'], 'two' => root['/two.rb']}, e.hashes)
  end
  
  def test_manifest_removes_duplicates_from_array_manifests
    e =  ManifestEnv.new :array_paths => ['/one', '/two', '/one', '/dir/.././one']
    assert_equal([root['/one'], root['/two']], e.arrays)
  end
  
  def test_manifest_method_registers_manifest_with_manifests_using_manifest_key
    e = ManifestEnv.new
    assert_equal({}, e.manifests)
    e.arrays
    assert_equal({:arrays => []}, e.manifests)
    e.hashes
    assert_equal({:arrays => [], :hashes => {}}, e.manifests)
  end
  
  #
  # Env#instantiate
  #
  
  def test_instantiate_doc
    e1 = Tap::Env.instantiate("./path/to/config.yml")
    e2 = Tap::Env.instantiate("./path/to/dir")

    assert_equal({
     File.expand_path("./path/to/config.yml") => e1, 
     File.expand_path("./path/to/dir/#{Tap::Env::DEFAULT_CONFIG_FILE}") => e2 },  
    Tap::Env.instances)
  end
  
  def test_instantiate_adds_new_env_to_instances_by_expanded_path
    assert Tap::Env.instances.empty?
    e = Tap::Env.instantiate("path.yml")
    assert_equal({File.expand_path("path.yml") => e}, Tap::Env.instances)
  end
  
  def test_instantiate_returns_env_with_root_directed_at_expaned_path_directory
    e = Tap::Env.instantiate("path/to/config.yml")
    assert_equal(File.expand_path("path/to/"), e.root.root)
  end
  
  def test_instantiate_appends_DEFAULT_CONFIG_FILE_to_directories
    e = Tap::Env.instantiate("path")
    assert_equal({File.expand_path("path/#{Tap::Env::DEFAULT_CONFIG_FILE}") => e}, Tap::Env.instances)
  end
  
  #
  # Env#instance_for test
  #
  
  def test_instantiate_for_returns_existing_env_in_instances
    e = Tap::Env.new
    Tap::Env.instances[File.expand_path("path.yml")] = e
    assert_equal(e, Tap::Env.instance_for("path.yml"))
  end
  
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
    
    assert count > 0
  end
  
  def test_activate_unshifts_load_paths_to_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
  
    e.activate
    
    assert_equal [root["/path/to/lib"], root["/path/to/another/lib"]], $LOAD_PATH
  end
  
  def test_activate_prioritizes_load_paths_in_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["post", root["/path/to/another/lib"], root["/path/to/lib"]]
    
    e.activate
    
    assert_equal [root["/path/to/lib"], root["/path/to/another/lib"], "post"], $LOAD_PATH
  end
  
  def test_activate_assigns_self_as_Env_instance
    assert_nil Tap::Env.instance
    e.activate
    assert_equal e, Tap::Env.instance
  end
  
  def test_activate_does_not_assign_self_as_Env_instance_if_already_set
    e.activate
    assert_equal e, Tap::Env.instance
    
    e1 = Tap::Env.new
    e1.activate
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
    
    assert count > 0
  end
  
  def test_deactivate_removes_load_paths_from_load_path_targets
    assert_equal [$LOAD_PATH], e.load_path_targets
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat [root["/path/to/lib"], root["/path/to/another/lib"]]
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
  
  def test_deactivate_unassigns_self_as_Env_instance
    e.activate
    assert_equal e, Tap::Env.instance
    
    e.deactivate
    assert_nil Tap::Env.instance
  end
  
  def test_deactivate_clears_manifests
    e.activate
    e.manifests[:key] = :value
    assert !e.manifests.empty?
    e.deactivate
    assert e.manifests.empty?
  end
  
  #
  # activate/deactivate test
  #
  
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
  
  def test_path_config_modification_through_accessors_raise_error_when_active
    e.activate
    assert_raise(RuntimeError) { e.load_paths = [] }
  end
  
  def test_recursive_activate_and_dectivate
    e1 = Tap::Env.new
    e1.load_paths = ["/path/to/e1"]
    e.envs << e1
    
    e2 = Tap::Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.envs << e2
    
    e3 = Tap::Env.new
    e3.load_paths = ["/path/to/e3"]
    e.envs << e3
    
    e.load_paths = ["/path/to/e"]
    $LOAD_PATH.clear
    e.activate
    
    assert e1.active?
    assert e2.active?
    assert e3.active?
    assert_equal ["/path/to/e", "/path/to/e1", "/path/to/e2",  "/path/to/e3"].collect {|p| root[p] }, $LOAD_PATH
    
    e.deactivate
    
    assert !e1.active?
    assert !e2.active?
    assert !e3.active?
    assert_equal [], $LOAD_PATH
  end
  
  def test_recursive_activate_and_dectivate_does_not_infinitely_loop
    e1 = Tap::Env.new
    e1.load_paths = ["/path/to/e1"]
    e.envs << e1
    
    e2 = Tap::Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.envs << e2
    e2.envs << e
    
    e.load_paths = ["/path/to/e"]
    $LOAD_PATH.clear
    e.activate
    
    assert e1.active?
    assert e2.active?
    assert_equal ["/path/to/e", "/path/to/e1", "/path/to/e2"].collect {|p| root[p] }, $LOAD_PATH
    
    e.deactivate
    
    assert !e1.active?
    assert !e2.active?
    assert_equal [], $LOAD_PATH
  end

  #
  # env_path test 
  #
  
  def test_env_path_returns_the_Env_instances_path_for_self
    Tap::Env.instances['/path'] = e
    assert_equal '/path', e.env_path
  end
  
  def test_env_path_returns_nil_if_self_is_not_in_Env_instances
    assert_equal({}, Tap::Env.instances)
    assert_nil e.env_path
  end
  
  #
  # env_paths test
  #
  
  def test_set_env_paths_instantiates_and_sets_envs
    assert_equal [], e.envs
    e.env_paths = ["path/to/file.yml", "path/to/dir"]
    
    e1 = Tap::Env.instances[File.expand_path("path/to/file.yml")]
    e2 = Tap::Env.instances[File.expand_path( "path/to/dir/#{Tap::Env::DEFAULT_CONFIG_FILE}")]
    
    assert_equal [e1, e2], e.envs
  end
  
  def test_set_env_paths_expands_and_sets_env_paths
    assert_equal [], e.env_paths
    e.env_paths = ["path/to/file.yml", "path/to/dir"]
    assert_equal [File.expand_path("path/to/file.yml"), File.expand_path( "path/to/dir/#{Tap::Env::DEFAULT_CONFIG_FILE}")], e.env_paths
  end
  
  def test_duplicate_envs_and_env_paths_are_filtered
    e.env_paths = ["path/to/dir/tap.yml", "path/to/dir"]

    path = File.expand_path( "path/to/dir/tap.yml" )
    e1 = Tap::Env.instances[path]
    
    assert_equal [path], e.env_paths
    assert_equal [e1], e.envs
  end
  
  #
  # reconfigure test
  #
  
  def test_reconfigure_reconfigures_root_before_reconfiguring_self
    assert_not_equal 'alt', root['lib']
    e.reconfigure({:load_paths => ['lib'], :directories => {'lib' => 'alt'}})
    
    assert_not_equal 'alt', root['lib']
    assert_equal [root['alt']], e.load_paths
  end
  
  def test_reconfigure_symbolizes_keys
    e.reconfigure({'load_paths' => ['lib'], 'directories' => {'lib' => 'alt'}})
    assert_equal [root['alt']], e.load_paths
  end

  def test_unused_configs_are_yielded_to_block
    was_in_block = false
    e.reconfigure(:another => :value) do |other_configs|
      was_in_block = true
      assert_equal({:another => :value}, other_configs)
    end
    
    assert was_in_block
  end
  
  def test_reconfigure_raises_error_when_active
    e.activate
    assert_raise(RuntimeError) { e.reconfigure }
  end
  
  def test_reconfigure_yields_to_block_even_if_no_other_configs_are_present
    was_in_block = false
    e.reconfigure({}) do |other_configs|
      was_in_block = true
      assert_equal({}, other_configs)
    end
    
    assert was_in_block
  end
  
  def test_configure_logs_unused_configs_if_no_block_is_given
    e.logger = MockLogger.new
    e.reconfigure(:unused => :value)
    
    assert_equal [[Logger::DEBUG, "ignoring non-env configs: unused", "warn"]], e.logger
  end
  
  def test_reconfigure_recursively_loads_env_paths
    config_file1 = method_tempfile
    config_file2 = method_tempfile
    config_file3 = method_tempfile
    
    File.open(config_file1, "w") do |file| 
      file << {:env_paths => config_file2}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:env_paths => config_file3}.to_yaml
    end
    
    File.open(config_file3, "w") do |file| 
    end
    
    e.reconfigure({:env_paths => config_file1})
    
    assert_equal [Tap::Env.instances[config_file1]], e.envs
    assert_equal [Tap::Env.instances[config_file2]], e.envs[0].envs
    assert_equal [Tap::Env.instances[config_file3]], e.envs[0].envs[0].envs
  end
  
  def test_recursive_loading_does_not_infinitely_loop
    config_file1 = method_tempfile
    config_file2 = method_tempfile
    
    File.open(config_file1, "w") do |file| 
      file << {:env_paths => config_file2}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:env_paths => config_file1}.to_yaml
    end
    
    assert_nothing_raised { e.reconfigure({:env_paths => config_file1}) }
    
    assert_equal [Tap::Env.instances[config_file1]], e.envs
    assert_equal [Tap::Env.instances[config_file2]], e.envs[0].envs
    assert_equal [Tap::Env.instances[config_file1]], e.envs[0].envs[0].envs
  end
  
  #
  # each test
  #
  
  def test_each_yields_each_env_in_order
    e1 = Tap::Env.new
    e2 = Tap::Env.new
    e3 = Tap::Env.new

    e.envs << e1
    e.envs << e3
    e1.envs << e2
    
    envs = []
    e.each {|env| envs << env}
    
    assert_equal [e, e1, e2, e3], envs
  end
  
  #
  # reverse_each test 
  #
  
  def test_reverse_each_yields_each_env_in_reverse_order
    e1 = Tap::Env.new
    e2 = Tap::Env.new
    e3 = Tap::Env.new

    e.envs << e1
    e.envs << e3
    e1.envs << e2
    
    envs = []
    e.reverse_each {|env| envs << env}
    
    assert_equal [e3, e2, e1, e], envs
  end
  
  #
  # lookup_paths test
  #
  
  def test_lookup_paths_returns_a_hash_mapping_a_reduced_root_path_to_an_env
    e1 = Tap::Env.new({}, Tap::Root.new('/path/to/env'))
    e2 = Tap::Env.new({}, Tap::Root.new('/path/to/another/env'))
    e3 = Tap::Env.new({}, Tap::Root.new('/path/to/environment'))

    e1.envs << e2
    e2.envs << e3
    
    assert_equal({'to/env' => e1, 'another/env' => e2, 'environment' => e3}, e1.lookup_paths)
  end
  
  def test_lookup_paths_raises_an_error_if_multiple_envs_map_to_the_same_lookup
    e1 = Tap::Env.new({}, Tap::Root.new('/path/to/env'))
    e2 = Tap::Env.new({}, Tap::Root.new('/path/to/env'))
    e1.envs << e2
    
    assert_raise(Tap::Env::InconsistencyError) { e1.lookup_paths }
    assert_raise(Tap::Env::InconsistencyError) { e1.lookup_paths(true) }
  end

  def test_reverse_lookup_paths_returns_a_hash_mapping_envs_to_a_reduced_root_path
    e1 = Tap::Env.new({}, Tap::Root.new('/path/to/env'))
    e2 = Tap::Env.new({}, Tap::Root.new('/path/to/another/env'))
    e3 = Tap::Env.new({}, Tap::Root.new('/path/to/environment'))

    e1.envs << e2
    e2.envs << e3
    
    assert_equal({e1 => 'to/env', e2 => 'another/env', e3 => 'environment'}, e1.lookup_paths(true))
  end
  
  #
  # lookup_paths_for test
  # 
  
  def expand(path)
    case path
    when Array then path.collect {|p| expand(p)}
    else File.expand_path(path)
    end
  end
  
  def lookup_test_setup
    e1 = ManifestEnv.new({
      :array_paths => expand(['/e1/one', '/e1/another/one', '/e1/two']), 
      :hash_paths => expand(['/e1/hash/one.rb', '/e1/hash/two.rb'])
    }, Tap::Root.new('/path/to/env'))
    e2 = ManifestEnv.new({
      :array_paths => expand(['/e2/two', '/e2/another/two', '/e2/three']), 
      :hash_paths => expand(['/e2/hash/two.rb', '/e2/hash/three.rb'])
    }, Tap::Root.new('/path/to/another/env'))
    e3 = ManifestEnv.new({
      :array_paths => expand(['/e3/three', '/e3/another/three', '/e3/four']), 
      :hash_paths => expand(['/e3/hash/three.rb', '/e3/hash/four.rb'])
    }, Tap::Root.new('/path/to/environment'))

    e1.envs << e2
    e2.envs << e3
    
    [e1, e2, e3]
  end

  def test_lookup_paths_for_maps_reduced_path_to_manifest_object_for_the_env
    e1, e2, e3 = lookup_test_setup

    assert_equal({
      e1 => [['another/one', expand('/e1/another/one')], ['e1/one', expand('/e1/one')], ['two', expand('/e1/two')]],
      e2 => [['another/two', expand('/e2/another/two')], ['e2/two', expand('/e2/two')], ['three', expand('/e2/three')]],
      e3 => [['another/three', expand('/e3/another/three')], ['e3/three', expand('/e3/three')], ['four', expand('/e3/four')]]
    }, e1.lookup_paths_for(:arrays))

    assert_equal({
      e1 => [['one', ['one', expand('/e1/hash/one.rb')]], ['two', ['two', expand('/e1/hash/two.rb')]]],
      e2 => [['three', ['three', expand('/e2/hash/three.rb')]], ['two', ['two', expand('/e2/hash/two.rb')]]],
      e3 => [['four', ['four', expand('/e3/hash/four.rb')]], ['three', ['three', expand('/e3/hash/three.rb')]]]
    }, e1.lookup_paths_for(:hashes))
  end
  
  #
  # lookup test
  #
  
  def test_lookup_arrays_cascades_through_evns_to_manifest_object_ending_in_pattern
    e1, e2, e3 = lookup_test_setup
    
    assert_equal(expand('/e1/one'), e1.lookup(:arrays, 'one'))
    assert_equal(expand('/e1/two'), e1.lookup(:arrays, 'two'))
    assert_equal(expand('/e2/three'), e1.lookup(:arrays, 'three'))
    assert_equal(expand('/e3/four'), e1.lookup(:arrays, 'four'))
    assert_equal(nil, e1.lookup(:arrays, 'five'))
    assert_equal(nil, e2.lookup(:arrays, 'one'))
  end
  
  def test_lookup_arrays_only_searches_env_mapped_to_root_pattern
    e1, e2, e3 = lookup_test_setup
    
    assert_equal(expand('/e1/one'), e1.lookup(:arrays, 'to/env:one'))
    assert_equal(expand('/e1/two'), e1.lookup(:arrays, 'to/env:two'))
    assert_equal(expand('/e2/two'), e1.lookup(:arrays, 'another/env:two'))
    assert_equal(nil, e1.lookup(:arrays, 'to/env:three'))
  end
  
  def test_lookup_hashes_cascades_through_evns_to_manifest_path_ending_in_pattern
    e1, e2, e3 = lookup_test_setup
    
    assert_equal(['one', expand('/e1/hash/one.rb')], e1.lookup(:hashes, 'one'))
    assert_equal(['two', expand('/e1/hash/two.rb')], e1.lookup(:hashes, 'two'))
    assert_equal(['three', expand('/e2/hash/three.rb')], e1.lookup(:hashes, 'three'))
    assert_equal(['four', expand('/e3/hash/four.rb')], e1.lookup(:hashes, 'four'))
    assert_equal(nil, e1.lookup(:hashes, 'four.rb'))
    assert_equal(nil, e1.lookup(:hashes, 'five'))
    assert_equal(nil, e2.lookup(:hashes, 'one'))
  end
  
  def test_lookup_hashes_only_searches_env_mapped_to_root_pattern
    e1, e2, e3 = lookup_test_setup
    
    assert_equal(['one', expand('/e1/hash/one.rb')], e1.lookup(:hashes, 'to/env:one'))
    assert_equal(['two', expand('/e1/hash/two.rb')], e1.lookup(:hashes, 'to/env:two'))
    assert_equal(['two', expand('/e2/hash/two.rb')], e1.lookup(:hashes, 'another/env:two'))
    assert_equal(nil, e1.lookup(:hashes, 'to/env:three'))
  end
  
  def test_lookup_raises_error_if_env_cannot_be_found
    e1, e2, e3 = lookup_test_setup
    assert_raise(ArgumentError) { e1.lookup(:arrays, 'non_existant:one') }
    assert_raise(ArgumentError) { e2.lookup(:arrays, 'to/env:one') }
  end
  
end