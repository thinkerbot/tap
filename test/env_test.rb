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
  # unshift test
  #
  
  def test_unshift_unshifts_env_onto_envs_removing_duplicates
    e1 = Tap::Env.new
    e2 = Tap::Env.new
    
    assert e.envs.empty?
    
    e.unshift(e1)
    assert_equal [e1], e.envs
    
    e.unshift(e2)
    assert_equal [e2, e1], e.envs
    
    e.unshift(e1)
    assert_equal [e1, e2], e.envs
  end
  
  def test_self_cannot_be_unshift_onto_self
    assert e.envs.empty?
    e.unshift(e)
    assert e.envs.empty?
  end
  
  #
  # push test
  #
  
  def test_push_pushes_env_onto_envs_removing_duplicates
    e1 = Tap::Env.new
    e2 = Tap::Env.new
    
    assert e.envs.empty?
    
    e.push(e1)
    assert_equal [e1], e.envs
    
    e.push(e2)
    assert_equal [e1, e2], e.envs
    
    e.push(e1)
    assert_equal [e2, e1], e.envs
  end
  
  def test_self_cannot_be_pushed_onto_self
    assert e.envs.empty?
    e.push(e)
    assert e.envs.empty?
  end
  
  #
  # each test
  #
  
  def test_each_yields_each_env_in_order
    a = Tap::Env.new
    b = Tap::Env.new
    c = Tap::Env.new
    d = Tap::Env.new

    a.push b
    b.push c
    a.push d
    
    envs = []
    a.each {|env| envs << env}
    
    assert_equal [a, b, c, d], envs
  end
  
  def test_each_only_yields_first_occurence_of_an_env
    a = Tap::Env.new
    b = Tap::Env.new
    c = Tap::Env.new
    d = Tap::Env.new

    a.push b
    b.push c
    a.push d
    c.push b
    
    envs = []
    a.each {|env| envs << env}
    
    assert_equal [a, b, c, d], envs
  end
  
  #
  # reverse_each test 
  #
  
  def test_reverse_each_yields_each_env_in_reverse_order
    a = Tap::Env.new
    b = Tap::Env.new
    c = Tap::Env.new
    d = Tap::Env.new

    a.push b
    b.push c
    a.push d
    
    envs = []
    a.reverse_each {|env| envs << env}
    
    assert_equal [d, c, b, a], envs
  end
  
  def test_reverse_each_only_yields_first_occurence_of_an_env
    a = Tap::Env.new
    b = Tap::Env.new
    c = Tap::Env.new
    d = Tap::Env.new

    a.push b
    b.push c
    a.push d
    c.push b
    
    envs = []
    a.reverse_each {|env| envs << env}
    
    assert_equal [d, c, b, a], envs
  end
  
  #
  # count test
  #
  
  def test_count_returns_total_number_of_unique_nested_envs
    e1 = Tap::Env.new
    e2 = Tap::Env.new
    e3 = Tap::Env.new
    
    e.push e1
    e1.push e2
    e2.push e3

    assert_equal 4, e.count
    assert_equal 1, e3.count
    
    e3.push e1
    assert_equal 3, e3.count
  end
  
  #
  # load_path_targets test
  #
  
  def test_load_path_targets_is_LOAD_PATH
    assert_equal [$LOAD_PATH], e.load_path_targets
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
    e.push e1
    
    e2 = Tap::Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.push e2
    
    e3 = Tap::Env.new
    e3.load_paths = ["/path/to/e3"]
    e.push e3
    
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
    e.push e1
    
    e2 = Tap::Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.push e2
    e2.push e
    
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
  # manifest test
  #
  
  class MEnv < Tap::Env
    attr_accessor :manifest_glob_items
  end

  def test_manifest_collects_items
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["three", 3]]
    assert_equal([["one", 1],["two", 2],["three", 3]], m.manifest(:items).entries)
  end

  def test_manifest_is_complete_after_manifest
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["three", 3]]

    assert m.manifest(:items).complete?
  end

  def test_manifest_yields_each_pair_to_block_in_order
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["three", 3]]

    recollected = []
    m.manifest(:items) do |key, value|
      recollected << [key, value]
    end

    assert_equal m.manifest_glob_items, recollected
  end

  def test_manifest_yields_each_pair_to_block_in_order_even_for_incomplete_manifest
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["three", 3]]

    recollected = []
    m.manifest(:items) do |key, value|
      recollected << [key, value]
      break
    end

    assert_equal [["one", 1]], recollected
    assert !m.manifests[:items].complete?

    recollected = []
    m.manifest(:items) do |key, value|
      recollected << [key, value]
    end

    assert_equal m.manifest_glob_items, recollected
    assert m.manifests[:items].complete?
  end

  def test_manifest_yields_manifest_or_break_value
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["three", 3]]

    result = m.manifest(:items) {|key, value|}
    assert_equal m.manifests[:items], result

    m.manifests[:items] = nil

    result = m.manifest(:items)
    assert_equal m.manifests[:items], result

    result = m.manifest(:items) do |key, value|
      break(nil)
    end

    assert_nil result
  end

  def test_manifest_does_not_raise_an_error_for_duplicate_items
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["one", 1]]
    assert_nothing_raised { m.manifest(:items) }
  end

  def test_manifest_raises_an_error_if_the_same_key_points_to_multiple_values
    m = MEnv.new
    m.manifest_glob_items = [["one", 1],["two", 2],["one", 3]]
    assert_raise(Tap::Support::Manifest::ManifestConflict) { m.manifest(:items) }
  end

  #
  # Tap::Root.minimal_map test
  #
  
  # def test_minimal_map_minimizes_keys_in_hash
  #   assert_equal([['c.d', 'one'], ['c.e', 'two']], Tap::Root.minimal_map({'a/b/c.d' => 'one', 'a/b/c.e' => 'two'}))
  #   assert_equal([['c', 'three'], ['b/c', 'two'], ['a/b/c', 'one']], Tap::Root.minimal_map({'a/b/c' => 'one', 'b/c' => 'two', 'c' => 'three'}))
  # end
  # 
  # def test_minimal_map_in_reverse_mode_maps_values_to_minimized_keys
  #   assert_equal([['one', 'c.d'], ['two', 'c.e']], Tap::Root.minimal_map({'a/b/c.d' => 'one', 'a/b/c.e' => 'two'}, true))
  # end

end