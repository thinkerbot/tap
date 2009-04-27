require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'
require 'rubygems'

class EnvTest < Test::Unit::TestCase
  include Tap::Env::Utils
  include MethodRoot
  
  Env = Tap::Env
  
  attr_reader :e
  
  def setup
    super
    @e = Env.new method_root
  end
  
  #
  # COMPOUND_KEY test
  #
  
  def test_COMPOUND_KEY_regexp
    r = Env::COMPOUND_KEY
    
    # key only
    assert r =~ "key"
    assert_equal ["key", nil], [$1, $2]
    
    assert r =~ "path/to/key"
    assert_equal ["path/to/key", nil], [$1, $2]
    
    assert r =~ "/path/to/key"
    assert_equal ["/path/to/key", nil], [$1, $2]
    
    assert r =~ "C:/path/to/key"
    assert_equal ["C:/path/to/key", nil], [$1, $2]
    
    assert r =~ 'C:\path\to\key'
    assert_equal ['C:\path\to\key', nil], [$1, $2]
    
    # env_key and key
    assert r =~ "env_key:key"
    assert_equal ["env_key", "key"], [$1, $2]
    
    assert r =~ "path/to/env_key:path/to/key"
    assert_equal ["path/to/env_key", "path/to/key"], [$1, $2]
    
    assert r =~ "/path/to/env_key:/path/to/key"
    assert_equal ["/path/to/env_key", "/path/to/key"], [$1, $2]
    
    assert r =~ "C:/path/to/env_key:C:/path/to/key"
    assert_equal ["C:/path/to/env_key", "C:/path/to/key"], [$1, $2]
    
    assert r =~ 'C:\path\to\env_key:C:\path\to\key'
    assert_equal ['C:\path\to\env_key', 'C:\path\to\key'], [$1, $2]
    
    assert r =~ "/path/to/env_key:C:/path/to/key"
    assert_equal ["/path/to/env_key", "C:/path/to/key"], [$1, $2]
    
    assert r =~ "C:/path/to/env_key:/path/to/key"
    assert_equal ["C:/path/to/env_key", "/path/to/key"], [$1, $2]
    
    assert r =~ "a:b"
    assert_equal ["a", "b"], [$1, $2]
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    e = Env.new
    assert_equal Dir.pwd, e.root.root
    assert_equal [], e.envs
    assert !e.active?
  end
  
  def test_initialize_from_path
    e = Env.new(".")
    assert_equal Dir.pwd, e.root.root
  end
  
  def test_initialize_from_Env
    root = Tap::Root.new
    e = Env.new(root)
    assert_equal root, e.root
  end
  
  def test_initialize_from_config
    r = Tap::Root.new
    e = Env.new(:root => r)
    assert_equal r, e.root
    
    e = Env.new(:root => ".")
    assert_equal Dir.pwd, e.root.root
    
    e = Env.new(:root => {:relative_paths => {:key => 'value'}})
    assert_equal({:key => 'value'}, e.root.relative_paths)
  end
  
  def test_initialize_loads_configurations_from_basename
    method_root.prepare('config.yml') do |io|
      io << YAML.dump(:key => 'value')
    end
    
    e = Env.new(method_root, 'config.yml')
    assert_equal "value", e.config[:key]
  end
  
  def test_initialize_does_not_load_configurations_if_configs_initialize_self
    method_root.prepare('config.yml') do |io|
      io << YAML.dump(:key => 'value')
    end
    
    e = Env.new({:root => method_root}, 'config.yml')
    assert_equal nil, e.config[:key]
  end
  
  def test_initialize_registers_self_in_cache
    cache = {}
    e = Env.new(method_root, nil, cache)
    assert_equal [e], cache[:env]
  end
  
  def test_initialize_raises_error_if_cache_contains_an_env_with_the_same_root_root
    r1 = Tap::Root.new
    r2 = Tap::Root.new
    assert_equal r1.root, r2.root
    
    cache = {:env => [Env.new(r1)]}
    err = assert_raises(RuntimeError) { Env.new(r2, nil, cache) }
    assert_equal "cache already has an env for: #{r2.root}", err.message
  end
  
  #
  # env_paths test
  #
  
  def test_initialize_adds_envs_for_env_paths
    e = Env.new :env_paths => ["one", "two"]
    assert_equal [
      File.expand_path("one"), 
      File.expand_path("two")
    ], e.envs.collect {|env| env.root.root } 
  end
  
  def test_duplicate_envs_and_env_paths_are_filtered
    e.env_paths = ["path/to/dir", "path/to/dir"]
    assert_equal [
      method_root.path("path/to/dir")
    ], e.envs.collect {|env| env.root.root } 
  end
  
  def test_set_env_paths_loads_string_inputs_as_yaml
    e.env_paths = "[one, two]"
    assert_equal [
      method_root.path("one"),
      method_root.path("two")
    ], e.envs.collect {|env| env.root.root }
  end
  
  def test_set_env_recursively_initializes_configured_envs
    one = method_root[:one]
    two = method_root[:two]
    three = method_root[:three]
    
    method_root.prepare(:one, 'config.yml') do |file| 
      file << YAML.dump({:env_paths => two})
    end
    method_root.prepare(:two, 'config.yml') do |file| 
      file << YAML.dump({:env_paths => three})
    end
    
    # one loads one/config.yml, which sets two as an env
    # two loads two/config.yml, which sets three as an env
    e = Env.new({:env_paths => one}, "config.yml")
    
    assert_equal [one], e.envs.collect {|env| env.path }
    assert_equal [two], e.envs[0].envs.collect {|env| env.path }
    assert_equal [three], e.envs[0].envs[0].envs.collect {|env| env.path }
  end
  
  def test_recursive_envs_do_not_infinitely_loop
    one = method_root[:one]
    two = method_root[:two]

    method_root.prepare(:one, 'config.yml') do |file| 
      file << YAML.dump({:env_paths => two})
    end
    method_root.prepare(:two, 'config.yml') do |file| 
      file << YAML.dump({:env_paths => one})
    end
    
    # one loads one/config.yml, which sets two as an env
    # two loads two/config.yml, which sets one as an env
    e = Env.new({:env_paths => one}, "config.yml")
    
    assert_equal [one], e.envs.collect {|env| env.path }
    assert_equal [two], e.envs[0].envs.collect {|env| env.path }
    assert_equal [one], e.envs[0].envs[0].envs.collect {|env| env.path }
  end
  
  #
  # gems test
  #
  
  module MockGem
    attr_accessor :full_gem_path
  end
  
  ONE = Gem::Specification.new do |s|
    s.name = "gem_mock"
    s.version = "1.0"
    s.extend MockGem
    s.full_gem_path = File.expand_path("mock_one")
  end
  TWO = Gem::Specification.new do |s|
    s.name = "gem_mock"
    s.version = "2.0"
    s.extend MockGem
    s.full_gem_path = File.expand_path("mock_two")
  end
  THREE = Gem::Specification.new do |s|
    s.name = "mock_gem"
    s.version = "1.0"
    s.extend MockGem
    s.full_gem_path = File.expand_path("mock_three")
  end
  
  def gem_test
    begin
      Gem.source_index.add_specs(ONE, TWO, THREE)
      yield
    ensure
      [ONE, TWO, THREE].each do |spec|
        Gem.source_index.remove_spec(spec.full_name)
      end
    end
  end
  
  def test_gem_test
    one_two = Gem::Dependency.new("gem_mock", ">= 1.0")
    two = Gem::Dependency.new("gem_mock", "> 1.0")
    assert_equal [], Gem.source_index.search(one_two)
    
    was_in_block = false
    gem_test do
      assert_equal [ONE, TWO], Gem.source_index.search(one_two)
      assert_equal [TWO], Gem.source_index.search(two)
      was_in_block = true
    end
    
    assert_equal [], Gem.source_index.search(one_two)
    assert was_in_block
  end
  
  def test_initialize_adds_envs_for_gems
    gem_test do
      e = Env.new :gems => ["gem_mock", "mock_gem"]
      assert_equal [TWO, THREE], e.gems
      assert_equal [
        TWO.full_gem_path, 
        THREE.full_gem_path
      ], e.envs.collect {|env| env.root.root } 
    end
  end
  
  def test_gems_respects_versions
    gem_test do
      e.gems = ["gem_mock < 2.0"]
      assert_equal [ONE], e.gems
    end
  end
  
  def test_gems_may_be_set_to_nil_a_YAML_string_etc
    gem_test do
      e.gems = nil
      assert_equal [], e.gems
      
      e.gems = "[gem_mock < 2.0, mock_gem]"
      assert_equal [ONE, THREE], e.gems
      
      e.gems = ["gem_mock", nil, nil, "mock_gem", nil]
      assert_equal [TWO, THREE], e.gems
    end
  end
  
  def test_gems_selects_all_with_all
    gem_test do
      e.gems = :all
      gems = Gem.source_index.gems.collect {|(name, spec)| spec }
      assert gems.sort == e.gems.sort
    end
  end
  
  def test_gems_selects_latest_with_latest
    gem_test do
      e.gems = :latest
      gems = Gem.source_index.latest_specs
      assert gems.sort == e.gems.sort
    end
  end
  
  def test_gems_does_not_activate_gems
    gem_test do
      e.gems = ["gem_mock < 2.0"]
      assert !Gem.loaded_specs.values.include?(ONE)
    end
  end

  #
  # envs= test
  #
  
  def test_set_envs_removes_duplicates_and_self
    a, b, c = Array.new(3) { Env.new }
    
    a.envs = [a, b, b, c]
    assert_equal [b, c], a.envs
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
    a,b,c,d,e = ('a'..'e').collect {|name| Env.new(:name => name) }

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
  # register test
  #
  
  def test_register_stores_an_object_in_the_registry
    assert_equal nil, e.registry[:path]
    e.register(:path, 'a/b/c')
    e.register(:path, 'd/e/f')
    assert_equal ['a/b/c', 'd/e/f'], e.registry[:path]
  end
  
  def test_register_does_not_store_objects_twice
    e.register(:path, 'a/b/c')
    e.register(:path, 'a/b/c')
    e.register(:path, 'a/b/c')
    assert_equal ['a/b/c'], e.registry[:path]
  end
  
  #
  # registered_objects test
  #
  
  def test_registered_objects_returns_a_minimap_array
    assert_equal nil, e.registry[:path]
    assert_equal [], e.registered_objects(:path)
    assert e.registered_objects(:path).kind_of?(Env::Minimap)
  end
  
  #
  # seek test
  #
  
  def test_seek_traverses_env_for_first_matching_resource_of_the_specified_type
    e1 = Env.new :root => method_root['a'], :registry => {:type => ["a/one.txt", "a/two.txt"] }
    e2 = Env.new :root => method_root['b'], :registry => {:type => ["b/one.txt", "b/three.txt"] }
    e1.push e2
    
    assert_equal "a/one.txt", e1.seek(:type, "one")
    assert_equal "a/two.txt", e1.seek(:type, "two")
    assert_equal "b/three.txt", e1.seek(:type, "three")
    
    assert_equal nil, e1.seek(:type, "a:three")
    assert_equal "a/one.txt", e1.seek(:type, "a:one")
    assert_equal "b/one.txt", e1.seek(:type, "b:one")
    assert_equal nil, e1.seek(:type, "b:two")
    assert_equal nil, e1.seek(:type, "c:one")
    assert_equal nil, e1.seek(:type, "four")
    
    assert_equal "b/one.txt", e2.seek(:type, "one")
    assert_equal nil, e2.seek(:type, "two")
  end
  
  #
  # manifest.seek test
  #
  
  def test_seek_for_manifest
    a_one = method_root.prepare("a/one.txt") { }
    a_two = method_root.prepare("a/two.txt") { }
    b_one = method_root.prepare("b/one.txt") { }
    b_three = method_root.prepare("b/three.txt") { }
    
    e1 = Env.new(method_root['a'])
    e2 = Env.new(method_root['b'])
    e1.push e2
    
    m = e1.manifest(:type) do |env|
      env.root.glob(:root)
    end
    
    assert_equal a_one, m.seek("one")
    assert_equal a_two, m.seek("two")
    assert_equal b_three, m.seek("three")
    
    assert_equal nil, m.seek("a:three")
    assert_equal a_one, m.seek("a:one")
    assert_equal b_one, m.seek("b:one")
    assert_equal nil, m.seek("b:two")
    assert_equal nil, m.seek("c:one")
    assert_equal nil, m.seek("four")
  end
  
  def test_manifest_seek_with_versions
    e1 = Env.new(Env::Root.new("/path/to/e1"))
    e2 = Env.new(Env::Root.new("/path/to/e2"))
    e1.push e2
    
    m = e1.manifest(:type) do |env|
      [ "/path/to/one-0.1.0.txt",
        "/path/to/two.txt",
        "/path/to/another/one.txt",
        "/path/to/one-0.2.0.txt", 
      ].collect do |entry|
        "/#{File.basename(env.root.root)}#{entry}"
      end
    end
    
    # simple search of e1
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("e1/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("/e1/path/to/one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("one-0.1.0")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("one-0.1.0.txt")
    
    assert_equal "/e1/path/to/two.txt", m.seek("two")
    assert_equal "/e1/path/to/another/one.txt", m.seek("another/one")
    assert_equal "/e1/path/to/one-0.2.0.txt", m.seek("one-0.2.0")
    
    # check e1 searches e2
    assert_equal "/e2/path/to/one-0.1.0.txt", m.seek("/e2/path/to/one")
    assert_equal "/e2/path/to/one-0.1.0.txt", m.seek("/e2/path/to/one-0.1.0")
    assert_equal "/e2/path/to/one-0.1.0.txt", m.seek("/e2/path/to/one-0.1.0.txt")
    
    # check with env pattern
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("e1:one")
    assert_equal "/e1/path/to/one-0.1.0.txt", m.seek("/path/to/e1:one")
  
    assert_equal "/e2/path/to/one-0.1.0.txt", m.seek("e2:one")
    assert_equal "/e2/path/to/one-0.1.0.txt", m.seek("/path/to/e2:to/one")
    
    # a variety of nil cases
    assert_nil m.seek("e3:one")
    assert_nil m.seek("another/path/to/e1:one")
    assert_nil m.seek("/another/path/to/one")
    assert_nil m.seek("/path/to")
    assert_nil m.seek("non_existant")
  end

  #
  # manifest.inspect test
  #
  
  def test_inspect_for_manifest
    a_one = method_root.prepare("a/one.txt") {|io| io << "::one"}
    a_two = method_root.prepare("a/two.txt") {|io| io << "::two"}
    b_one = method_root.prepare("b/one.txt") {|io| io << "::one"}
    b_three = method_root.prepare("b/three.txt") {|io| io << "::three"}
    
    e1 = Env.new(method_root['a'])
    e2 = Env.new(method_root['b'])
    e1.push e2
    
    m = e1.manifest(:type) do |env|
      env.root.glob(:root)
    end
    
    template = %Q{<%= env_key %>:
<% manifest.minimap.each do |key, value| %>
  <%= key %>: <%= File.basename(value) %>
<% end %>
}

    assert_equal %q{
a:
  one: one.txt
  two: two.txt
b:
  one: one.txt
  three: three.txt
}, "\n" + m.inspect(template)
  end
  
  #
  # inspect test
  #
  
  def test_inspect_visits_ERB_template_with_each_env_and_env_key
    a,b,c,d,e = ('a'..'e').collect {|name| Env.new(name) }

    a.push(b).push(c)
    b.push(d).push(e)
    
    template = "\n<%= env_key %><%= env.object_id %>"
    expected =  %Q{
a#{a.object_id}
b#{b.object_id}
d#{d.object_id}
e#{e.object_id}
c#{c.object_id}}
    assert_equal expected, a.inspect(template)
  end
  
  def test_inspect_passes_templates_to_block_before_templating
    a,b,c = ('a'..'c').collect {|name| Env.new(name) }

    a.push(b)
    b.push(c)
    
    count = 0
    result = a.inspect("<%= count %>") do |templater, globals|
      count += 1
      templater.count = count
    end
    assert_equal "123", result
  end
  
  def test_inspect_passes_globals_to_template
    a,b,c = ('a'..'c').collect {|name| Env.new(name) }

    a.push(b)
    b.push(c)
    
    result = a.inspect("<%= count %>(<%= total %>)\n", :total => 0) do |templater, globals|
      globals[:total] += 1
      templater.count = globals[:total]
    end
    assert_equal "1(3)\n2(3)\n3(3)\n", result
  end
end

class EnvActivateTest < Test::Unit::TestCase
  Env = Tap::Env
  
  attr_accessor :e
  
  def setup
    @current_instance = Env.instance
    Env.instance = nil
    
    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @e = Env.new
  end
  
  def teardown
    Env.instance = @current_instance
    $LOAD_PATH.clear
    $LOAD_PATH.concat(@current_load_paths)
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
  
  def test_activate_does_not_add_load_paths_unless_specified
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    
    e.set_load_paths = false
    e.activate
    
    assert_equal [], $LOAD_PATH
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
  
  def test_deactivate_does_not_remove_load_paths_unless_specified
    e.load_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.set_load_paths = false
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat [e.root["/path/to/lib"], e.root["/path/to/another/lib"]]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    e.deactivate
    
    assert_equal ["pre", e.root["/path/to/lib"], e.root["/path/to/another/lib"], "post"], $LOAD_PATH
  end
  
  def test_deactivate_unassigns_self_as_Env_instance
    e.activate
    assert_equal e, Env.instance
    
    e.deactivate
    assert_nil Env.instance
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
  # extra assurances
  #
  
  def test_gems_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.gems = [] }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  def test_env_paths_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.env_paths = [] }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  def test_envs_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.envs = [] }
    assert_equal "envs cannot be modified once active", err.message
  end
  
  def test_load_paths_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.load_paths = [] }
    assert_equal "load_paths cannot be modified once active", err.message
  end
  
  def test_set_load_paths_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.set_load_paths = false }
    assert_equal "set_load_paths cannot be modified once active", err.message
  end
end