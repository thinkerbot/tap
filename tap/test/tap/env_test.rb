require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'

class EnvTest < Test::Unit::TestCase
  include Tap
  
  acts_as_file_test
  
  attr_accessor :e
  
  def setup
    super
    
    @current_instance = Env.instance
    @current_instances = Env.instances
    Env.send(:class_variable_set, :@@instance, nil)
    Env.send(:class_variable_set, :@@instances, {})
    
    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @e = Env.new
  end
  
  def teardown
    super
    
    Env.send(:class_variable_set, :@@instance,  @current_instance)
    Env.send(:class_variable_set, :@@instances, @current_instances)
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat(@current_load_paths)
  end
  
  #
  # Env#manifest test
  #

  def test_manifest_adds_method_to_access_manifest_produced_by_block
    assert !e.respond_to?(:new_manifest)
    Env.manifest(:new_manifest) do |env|
      Support::Manifest.new ['a', 'b', 'c']
    end
    
    assert e.respond_to?(:new_manifest)
    assert_equal(['a', 'b', 'c'], e.new_manifest.entries)

    another = Env.new
    assert another.respond_to?(:new_manifest)
    assert_equal(['a', 'b', 'c'], another.new_manifest.entries)

    assert another.new_manifest.object_id !=  e.new_manifest.object_id
  end
  
  #
  # Env#instantiate
  #
  
  def test_instantiate_doc
    e1 = Env.instantiate("./path/to/config.yml")
    e2 = Env.instantiate("./path/to/dir")

    assert_equal({
     File.expand_path("./path/to/config.yml") => e1, 
     File.expand_path("./path/to/dir/#{Env::DEFAULT_CONFIG_FILE}") => e2 },  
    Env.instances)
  end
  
  def test_instantiate_adds_new_env_to_instances_by_expanded_path
    assert Env.instances.empty?
    e = Env.instantiate("path.yml")
    assert_equal({File.expand_path("path.yml") => e}, Env.instances)
  end
  
  def test_instantiate_returns_env_with_root_directed_at_expanded_path_directory
    e = Env.instantiate("path/to/config.yml")
    assert_equal(File.expand_path("path/to/"), e.root.root)
  end
  
  def test_instantiate_appends_DEFAULT_CONFIG_FILE_to_directories
    e = Env.instantiate("path")
    assert_equal({File.expand_path("path/#{Env::DEFAULT_CONFIG_FILE}") => e}, Env.instances)
  end
  
  def test_instantiate_returns_existing_env_in_instances
    e = Env.new
    Env.instances[File.expand_path("path.yml")] = e
    assert_equal(e, Env.instantiate("path.yml"))
  end
  
  #
  # initialization tests
  #
  
  def test_default_initialize
    e = Env.new
    assert_equal Dir.pwd, e.root.root
    assert_equal [], e.envs
    assert !e.active?
  end
  
  def test_Envs_may_be_initialized_from_paths
    e = Env.new(".")
    assert_equal Dir.pwd, e.root.root
  end
  
  def test_Envs_may_be_initialized_from_Roots
    root = Root.new
    e = Env.new(root)
    assert_equal root, e.root
  end
  
  def test_Envs_may_be_initialized_from_config_hashes
    e = Env.new(:root => {:relative_paths => {:key => 'value'}}, :load_paths => ['alt'])
    assert_equal({:key => 'value'}, e.root.relative_paths)
    assert_equal Root, e.root.class
    assert_equal [File.expand_path('alt')], e.load_paths
  end
  
  #
  # load_paths= test
  #
  
  def test_set_load_paths_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.load_paths = ['/path/to/lib'] }
    assert_equal "load_paths cannot be modified once active", err.message
  end
  
  def test_set_load_paths_via_config_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.config[:load_paths] = ['/path/to/lib'] }
    assert_equal "load_paths cannot be modified once active", err.message
  end
  
  #
  # env_paths= test
  #
  
  def test_set_env_paths_instantiates_and_sets_envs
    assert_equal [], e.envs
    e.env_paths = ["path/to/file.yml", "path/to/dir"]
    
    e1 = Env.instances[File.expand_path("path/to/file.yml")]
    e2 = Env.instances[File.expand_path( "path/to/dir/#{Env::DEFAULT_CONFIG_FILE}")]
    
    assert_equal [e1, e2], e.envs
  end
  
  def test_set_env_paths_expands_and_sets_env_paths
    assert_equal [], e.env_paths
    e.env_paths = ["path/to/file.yml", "path/to/dir"]
    assert_equal [File.expand_path("path/to/file.yml"), File.expand_path( "path/to/dir/#{Env::DEFAULT_CONFIG_FILE}")], e.env_paths
  end
  
  def test_duplicate_envs_and_env_paths_are_filtered
    e.env_paths = ["path/to/dir/tap.yml", "path/to/dir"]

    path = File.expand_path( "path/to/dir/tap.yml" )
    e1 = Env.instances[path]
    
    assert_equal [path], e.env_paths
    assert_equal [e1], e.envs
  end
  
  def test_set_env_paths_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.env_paths = ['/path/to/env'] }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  #
  # env_path test 
  #
  
  def test_env_path_returns_the_Env_instances_key_for_self
    Env.instances['/path'] = e
    assert_equal '/path', e.env_path
  end
  
  def test_env_path_returns_nil_if_self_is_not_in_Env_instances
    assert_equal({}, Env.instances)
    assert_nil e.env_path
  end
  
  #
  # envs= test
  #
  
  def test_set_envs_removes_duplicates_and_self
    a, b, c = Array.new(3) { Env.new }
    
    a.envs = [a, b, b, c]
    assert_equal [b, c], a.envs
  end
  
  def test_set_envs_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.envs = [Env.new] }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  #
  # unshift test
  #
  
  def test_unshift_unshifts_env_onto_envs_removing_duplicates
    a, b, c = Array.new(3) { Env.new }
    
    assert a.envs.empty?
    
    a.unshift(b)
    assert_equal [b], a.envs
    
    a.unshift(c)
    assert_equal [c, b], a.envs
    
    a.unshift(b)
    assert_equal [b, c], a.envs
  end
  
  def test_self_cannot_be_unshift_onto_self
    assert e.envs.empty?
    e.unshift(e)
    assert e.envs.empty?
  end
  
  def test_unshift_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.unshift(Env.new) }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  #
  # push test
  #
  
  def test_push_pushes_env_onto_envs_removing_duplicates
    a, b, c = Array.new(3) { Env.new }
    
    assert a.envs.empty?
    
    a.push(b)
    assert_equal [b], a.envs
    
    a.push(c)
    assert_equal [b, c], a.envs
    
    a.push(b)
    assert_equal [c, b], a.envs
  end
  
  def test_self_cannot_be_pushed_onto_self
    assert e.envs.empty?
    e.push(e)
    assert e.envs.empty?
  end
  
  def test_push_raises_error_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.push(Env.new) }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  #
  # each test
  #
  
  def test_each_yields_each_env_in_order
    a, b, c, d = Array.new(4) { Env.new }

    a.push b
    b.push c
    a.push d
    
    envs = []
    a.each {|env| envs << env}
    
    assert_equal [a, b, c, d], envs
  end
  
  def test_each_only_yields_first_occurence_of_an_env
    a, b, c, d = Array.new(4) { Env.new }

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
    a, b, c, d = Array.new(4) { Env.new }

    a.push b
    b.push c
    a.push d
    
    envs = []
    a.reverse_each {|env| envs << env}
    
    assert_equal [d, c, b, a], envs
  end
  
  def test_reverse_each_only_yields_first_occurence_of_an_env
    a, b, c, d = Array.new(4) { Env.new }

    a.push b
    b.push c
    a.push d
    c.push b
    
    envs = []
    a.reverse_each {|env| envs << env}
    
    assert_equal [d, c, b, a], envs
  end
  
  #
  # recursive_inject test
  #
  
  def test_recursive_inject_documentation
    a,b,c,d,e = ('a'..'e').collect {|name| Tap::Env.new.reconfigure(:name => name) }
  
    a.push(b).push(c)
    b.push(d).push(e)
  
    lines = []
    a.recursive_inject(0) do |nesting_depth, env|
      lines << "\n#{'..' * nesting_depth}#{env.config[:name]} (#{nesting_depth})"
      nesting_depth + 1
    end

    expected =  %Q{
a (0)
..b (1)
....d (2)
....e (2)
..c (1)}
    assert_equal expected, lines.join
  end
  
  def test_recursive_inject_passes_same_block_result_to_each_child
    a, b, c, d = Array.new(4) { Env.new }
    
    a.push(b).push(c)
    c.push(d)
    
    results = []
    a.recursive_inject(0) {|n, env| results << [env, n]; n+1}
    
    assert_equal [[a,0], [b,1], [c,1], [d,2]], results
  end
  
  def test_recursive_inject_only_injects_first_occurence_of_an_env
    a, b, c, d = Array.new(4) { Env.new }

    a.push b
    b.push c
    a.push d
    c.push b
    
    result = a.recursive_inject([]) {|envs, env| envs << env }
    assert_equal [a, b, c, d], result
  end
  
  #
  # reconfigure test
  #
  
  def test_reconfigure_reconfigures_root
    assert_equal [File.join(e.root.root, 'lib')], e.load_paths
    e.reconfigure(:load_paths => ['lib'], :root => {:relative_paths => {'lib' => 'alt'}})
    
    assert_equal [File.join(e.root.root, 'alt')], e.load_paths
  end

  def test_reconfigure_recursively_loads_env_paths
    config_file1 = method_root.prepare(:tmp, 'one')
    config_file2 = method_root.prepare(:tmp, 'two')
    config_file3 = method_root.prepare(:tmp, 'three')
    
    File.open(config_file1, "w") do |file| 
      file << {:env_paths => config_file2}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:env_paths => config_file3}.to_yaml
    end
    
    File.open(config_file3, "w") do |file| 
    end
    
    e.reconfigure({:env_paths => config_file1})
    
    assert_equal [Env.instances[config_file1]], e.envs
    assert_equal [Env.instances[config_file2]], e.envs[0].envs
    assert_equal [Env.instances[config_file3]], e.envs[0].envs[0].envs
  end
  
  def test_recursive_loading_does_not_infinitely_loop
    config_file1 = method_root.prepare(:tmp, 'one')
    config_file2 = method_root.prepare(:tmp, 'two')
    
    File.open(config_file1, "w") do |file| 
      file << {:env_paths => config_file2}.to_yaml
    end
  
    File.open(config_file2, "w") do |file| 
      file << {:env_paths => config_file1}.to_yaml
    end
    
    e.reconfigure({:env_paths => config_file1})
    
    assert_equal [Env.instances[config_file1]], e.envs
    assert_equal [Env.instances[config_file2]], e.envs[0].envs
    assert_equal [Env.instances[config_file1]], e.envs[0].envs[0].envs
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
  
  def test_activate_freezes_envs
    assert !e.envs.frozen?
    e.activate
    assert e.envs.frozen?
  end
  
  def test_activate_freezes_load_paths
    assert !e.load_paths.frozen?
    e.activate
    assert e.load_paths.frozen?
  end
  
  def test_activate_unshifts_load_paths_to_LOAD_PATH
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
  
    e.activate
    
    assert_equal [e.root["/path/to/lib"], e.root["/path/to/another/lib"]], $LOAD_PATH
  end
  
  def test_activate_prioritizes_load_paths_in_LOAD_PATH
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["post", e.root["/path/to/another/lib"], e.root["/path/to/lib"]]
    
    e.activate
    
    assert_equal [e.root["/path/to/lib"], e.root["/path/to/another/lib"], "post"], $LOAD_PATH
  end
  
  def test_activate_assigns_self_as_Env_instance
    assert_nil Env.instance
    e.activate
    assert_equal e, Env.instance
  end
  
  def test_activate_does_not_assign_self_as_Env_instance_if_already_set
    e.activate
    assert_equal e, Env.instance
    
    e1 = Env.new
    e1.activate
    assert_equal e, Env.instance
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
  
  def test_deactivate_unfreezes_envs
    e.activate
    assert e.envs.frozen?
    
    e.deactivate
    assert !e.envs.frozen?
  end
  
  def test_deactivate_unfreezes_load_paths
    e.activate
    assert e.load_paths.frozen?
    
    e.deactivate
    assert !e.load_paths.frozen?
  end
  
  def test_deactivate_removes_load_paths_from_LOAD_PATH
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat [e.root["/path/to/lib"], e.root["/path/to/another/lib"]]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    e.deactivate
    
    assert_equal ["pre", "post"], $LOAD_PATH
  end
  
  def test_deactivate_does_not_remove_load_paths_unless_deactivated
    Env.send(:class_variable_set, :@@instance, Env.new)
    
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["/path/to/lib", "/path/to/another/lib"]
    
    assert !e.active?
    assert !e.deactivate
    assert_equal ["/path/to/lib", "/path/to/another/lib"], $LOAD_PATH
  end
  
  def test_deactivate_unassigns_self_as_Env_instance
    e.activate
    assert_equal e, Env.instance
    
    e.deactivate
    assert_nil Env.instance
  end
  
  def test_deactivate_clears_manifests
    e.activate
    e.tasks.entries << "entry"
    assert !e.tasks.empty?
    e.deactivate
    assert e.tasks.empty?
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
  
  def test_recursive_activate_and_dectivate
    e1 = Env.new
    e1.load_paths = ["/path/to/e1"]
    e.push e1
    
    e2 = Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.push e2
    
    e3 = Env.new
    e3.load_paths = ["/path/to/e3"]
    e.push e3
    
    e.load_paths = ["/path/to/e"]
    $LOAD_PATH.clear
    e.activate
    
    assert e1.active?
    assert e2.active?
    assert e3.active?
    expected = ["/path/to/e", "/path/to/e1", "/path/to/e2",  "/path/to/e3"].collect {|p| e.root[p] }
    assert_equal expected, $LOAD_PATH
    
    e.deactivate
    
    assert !e1.active?
    assert !e2.active?
    assert !e3.active?
    assert_equal [], $LOAD_PATH
  end
  
  def test_recursive_activate_and_dectivate_does_not_infinitely_loop
    e1 = Env.new
    e1.load_paths = ["/path/to/e1"]
    e.push e1
    
    e2 = Env.new
    e2.load_paths = ["/path/to/e2"]
    e1.push e2
    e2.push e
    
    e.load_paths = ["/path/to/e"]
    $LOAD_PATH.clear
    e.activate
    
    assert e1.active?
    assert e2.active?
    expected = ["/path/to/e", "/path/to/e1", "/path/to/e2"].collect {|p| e.root[p] }
    assert_equal expected, $LOAD_PATH
    
    e.deactivate
    
    assert !e1.active?
    assert !e2.active?
    assert_equal [], $LOAD_PATH
  end
  
  #
  # manifest.search test
  #
  
  def test_search_calls_find_in_each_env_manifest_until_a_matching_value_is_found
    Env.manifest(:items) {|env| Support::Manifest.new }
    
    e1 = Env.new(Root.new("/path/to/e1"))
    e2 = Env.new(Root.new("/path/to/e2"))
    e1.push e2
    
    [ "/path/to/one-0.1.0.txt",
      "/path/to/two.txt",
      "/path/to/another/one.txt",
      "/path/to/one-0.2.0.txt", 
    ].each do |entry|
      e1.items.entries << "/e1#{entry}"
      e2.items.entries << "/e2#{entry}"
    end
    
    # simple search of e1
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("e1/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("/e1/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("one-0.1.0")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("one-0.1.0.txt")
    
    assert_equal "/e1/path/to/two.txt", e1.items.search("two")
    assert_equal "/e1/path/to/another/one.txt", e1.items.search("another/one")
    assert_equal "/e1/path/to/one-0.2.0.txt", e1.items.search("one-0.2.0")
    
    # check e1 searches e2
    assert_equal "/e2/path/to/one-0.1.0.txt", e1.items.search("/e2/path/to/one")
    assert_equal "/e2/path/to/one-0.1.0.txt", e1.items.search("/e2/path/to/one-0.1.0")
    assert_equal "/e2/path/to/one-0.1.0.txt", e1.items.search("/e2/path/to/one-0.1.0.txt")
    
    # check with env pattern
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("e1:one")
    assert_equal "/e1/path/to/one-0.1.0.txt", e1.items.search("/path/to/e1:one")

    assert_equal "/e2/path/to/one-0.1.0.txt", e1.items.search("e2:one")
    assert_equal "/e2/path/to/one-0.1.0.txt", e1.items.search("/path/to/e2:to/one")
    
    # a variety of nil cases
    assert_nil e1.items.search("e3:one")
    assert_nil e1.items.search("another/path/to/e1:one")
    assert_nil e1.items.search("/another/path/to/one")
    assert_nil e1.items.search("/path/to")
    assert_nil e1.items.search("non_existant")
  end
  
end