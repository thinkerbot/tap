require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'
require 'rubygems'
require 'tap/test'

# used in documentation test
class A; end
class B < A; end
class CustomTask
  def call; end
end

class EnvTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test :cleanup_dirs => [:root]

  Env = Tap::Env
  
  attr_reader :e
  
  def setup
    super
    @e = Env.new method_root
  end
  
  #
  # documentation test
  #
  
  def test_env_documentation
    # /one
    # |-- a.rb
    # `-- b.rb
    #
    # /two
    # |-- b.rb
    # `-- c.rb
    method_root.prepare(:one, 'a.rb') {|io|}
    method_root.prepare(:one, 'b.rb') {|io|}
    method_root.prepare(:two, 'b.rb') {|io|}
    method_root.prepare(:two, 'c.rb') {|io|}
    
    env =  Env.new(method_root[:one])
    env << Env.new(method_root[:two])
  
    assert_equal([method_root[:one], method_root[:two]], env.collect {|e| e.root.root})
    
    expected = [
      method_root.path(:one, "a.rb"),
      method_root.path(:one, "b.rb"),
      method_root.path(:two, "c.rb"),
    ]
    assert_equal expected, env.glob(:root, "*.rb")
  
    ###
  
    assert_equal method_root.path(:one, "a"), env.class_path(:root, A)
    assert_equal method_root.path(:one, "b"), env.class_path(:root, B)
  
    assert_equal method_root.path(:one, "a/index.html"), env.class_path(:root, A, "index.html")
    assert_equal method_root.path(:one, "b/index.html"), env.class_path(:root, B, "index.html")
  
    method_root.prepare(:two, "a/index.html") {}
  
    visited_paths = []
    actual = env.class_path(:root, B, "index.html") do |path|
      visited_paths << path
      File.exists?(path)
    end
    assert_equal method_root.path(:two, "a/index.html"), actual
  
    expected = [
      method_root.path(:one, "b/index.html"),
      method_root.path(:two, "b/index.html"),
      method_root.path(:one, "a/index.html"),
      method_root.path(:two, "a/index.html")
    ]
    assert_equal expected, visited_paths
    
    ###
    
    manifest = env.manifest {|e| e.root.glob(:root, "*.rb") }
    
    assert_equal method_root.path(:one, "a.rb"), manifest.seek("a")
    assert_equal method_root.path(:one, "b.rb"), manifest.seek("b")
    assert_equal method_root.path(:two, "c.rb"), manifest.seek("c")
  
    assert_equal method_root.path(:one, "b.rb"), manifest.seek("one:b")
    assert_equal method_root.path(:two, "b.rb"), manifest.seek("two:b")
    
    env.register(CustomTask).register_as(:task, "this is a custom task")
    
    const = env.constants.seek('custom_task')
    assert_equal "CustomTask", const.const_name
    assert_equal({:task => "this is a custom task"}, const.types)
    assert_equal CustomTask, const.constantize
    
    ###
    method_root.prepare(:one, "tap.yml") do |io|
      io.puts "env_paths: [#{method_root.path(:two)}]"
    end

    method_root.prepare(:two, "tap.yml") do |io|
      io.puts "env_paths: [#{method_root.path(:three)}]"
    end
  
    env = Env.new(method_root.path(:one), :basename => "tap.yml")
    assert_equal [
      method_root.path(:one),
      method_root.path(:two),
      method_root.path(:three)
    ], env.collect {|e| e.root.root}
  end
  
  #
  # setup test
  #
  
  def env_test
    current = {}
    ENV.each_pair do |key, value|
      current[key] = value
    end
    
    begin
      ENV.clear
      yield
    ensure
      ENV.clear
      current.each_pair do |key, value|
        ENV[key] = value
      end
    end
  end
  
  def test_setup_sets_dir_as_env_root
    env_test do
      env = Env.setup(method_root[:dir], nil)
      assert_equal method_root[:dir], env.root.root
    end
  end
  
  def test_setup_loads_configs_from_dir_config_file
    method_root.prepare('config.yml') do |io|
      io << "key: value"
    end
    
    env_test do
      env = Env.setup(method_root.root, 'config.yml')
      assert_equal 'value', env.config[:key]
    end
  end
  
  def test_setup_loads_configs_from_ENV
    env_test do
      ENV['TAP_KEY'] = 'value'
      
      env = Env.setup(method_root.root, nil)
      assert_equal 'value', env.config[:key]
    end
  end
  
  def test_setup_merges_default_global_user_configs
    method_root.prepare('config.yml') do |io|
      io << "key: user"
    end
    
    env_test do
      env = Env.setup(method_root.root, nil)
      assert_equal nil, env.config[:key]
    
      ENV['TAP_KEY'] = 'global'
      env = Env.setup(method_root.root, nil)
      assert_equal 'global', env.config[:key]
    
      env = Env.setup(method_root.root, 'config.yml')
      assert_equal 'user', env.config[:key]
    end
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    e = Env.new
    assert_equal Dir.pwd, e.root.root
    assert_equal [], e.envs
    assert !e.active?
    assert !e.invert?
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
    
    e = Env.new(method_root, :basename => 'config.yml')
    assert_equal "value", e.config[:key]
  end
  
  def test_initialize_does_not_load_configurations_when_configs_are_specified
    method_root.prepare('config.yml') do |io|
      io << YAML.dump(:key => 'value')
    end
    
    e = Env.new({:root => method_root}, :basename => 'config.yml')
    assert_equal nil, e.config[:key]
  end
  
  def test_initialize_raises_error_if_context_contains_an_env_with_the_same_root_root
    r1 = Tap::Root.new
    r2 = Tap::Root.new
    assert_equal r1.root, r2.root
    
    context = Env.new(r1).context
    assert_equal(true, context.instances.any? {|env| env.root.root == r2.root})
    
    err = assert_raises(RuntimeError) { Env.new(r2, context) }
    assert_equal "context already has an env for: #{r2.root}", err.message
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
    e = Env.new({:env_paths => one}, :basename => "config.yml")
    
    assert_equal [one], e.envs.collect {|env| env.root.root }
    assert_equal [two], e.envs[0].envs.collect {|env| env.root.root }
    assert_equal [three], e.envs[0].envs[0].envs.collect {|env| env.root.root }
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
    e = Env.new({:env_paths => one}, :basename => "config.yml")
    
    assert_equal [one], e.envs.collect {|env| env.root.root }
    assert_equal [two], e.envs[0].envs.collect {|env| env.root.root }
    assert_equal [one], e.envs[0].envs[0].envs.collect {|env| env.root.root }
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
  
  def gem_test(*specs)
    begin
      Gem.source_index.add_specs(*specs)
      yield
    ensure
      specs.each do |spec|
        Gem.source_index.remove_spec(spec.full_name)
      end
    end
  end
  
  def test_gem_test
    one_two = Gem::Dependency.new("gem_mock", ">= 1.0")
    two = Gem::Dependency.new("gem_mock", "> 1.0")
    assert_equal [], Gem.source_index.search(one_two)
    
    was_in_block = false
    gem_test(ONE, TWO, THREE) do
      assert_equal [ONE, TWO], Gem.source_index.search(one_two)
      assert_equal [TWO], Gem.source_index.search(two)
      was_in_block = true
    end
    
    assert_equal [], Gem.source_index.search(one_two)
    assert was_in_block
  end
  
  def test_initialize_adds_envs_for_gems
    gem_test(ONE, TWO, THREE) do
      e = Env.new :gems => ["gem_mock", "mock_gem"]
      assert_equal [TWO, THREE], e.gems
      assert_equal [
        TWO.full_gem_path, 
        THREE.full_gem_path
      ], e.envs.collect {|env| env.root.root } 
    end
  end
  
  def test_gems_respects_versions
    gem_test(ONE, TWO, THREE) do
      e.gems = ["gem_mock < 2.0"]
      assert_equal [ONE], e.gems
    end
  end
  
  def test_gems_may_be_set_to_nil_a_YAML_string_etc
    gem_test(ONE, TWO, THREE) do
      e.gems = nil
      assert_equal [], e.gems
      
      e.gems = "[gem_mock < 2.0, mock_gem]"
      assert_equal [ONE, THREE], e.gems
      
      e.gems = ["gem_mock", nil, nil, "mock_gem", nil]
      assert_equal [TWO, THREE], e.gems
    end
  end
  
  def test_gems_selects_all_with_ALL
    gem_test do
      e.gems = :ALL
      gems = Gem.source_index.gems.collect {|(name, spec)| spec }
      assert gems.sort == e.gems.sort
    end
  end
  
  def test_gems_selects_latest_with_LATEST
    gem_test do
      e.gems = :LATEST
      gems = Gem.source_index.latest_specs
      assert gems.sort == e.gems.sort
    end
  end
  
  def test_gems_does_not_activate_gems
    gem_test(ONE, TWO, THREE) do
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
  # constants test
  #
  
  def test_constants_scans_const_paths_for_resources
    path = method_root.prepare(:lib, 'a.rb') do |io|
      io.puts "# A::resource"
      io.puts "# B::resource"
      io.puts "# B::alt"
    end
    
    assert_equal ["A", "B"], e.constants.collect {|const| const.const_name }
    assert_equal [["resource"], ["resource", "alt"]], e.constants.collect {|const| const.types.keys }
  end
  
  #
  # AGET test
  #
  
  class Alpha
  end
  
  class Beta
  end
  
  def test_AGET_seeks_constant_for_key
    e.register(Alpha)
    e.register(Beta)
    
    assert_equal Alpha, e['alpha']
    assert_equal Beta, e['beta']
    assert_equal Beta, e['env_test/beta']
    assert_equal Beta, e['test_AGET_seeks_constant_for_key:env_test/beta']
    assert_equal nil, e['gamma']
  end
  
  def test_inverted_AGET_seeks_key_for_constant
    e.register(Alpha)
    e.register(Beta)
    
    assert_equal 'test_inverted_AGET_seeks_key_for_constant:alpha', e[Alpha, true]
    assert_equal 'test_inverted_AGET_seeks_key_for_constant:beta', e[Beta, true]
  end
  
  #
  # invert? invert! invert test
  #
  
  def test_invert_bang_flips_invert_question
    assert_equal false, e.invert?
    e.invert!
    assert_equal true, e.invert?
    e.invert!
    assert_equal false, e.invert?
  end
  
  def test_invert_bang_returns_self
    assert_equal e, e.invert!
  end
  
  def test_invert_returns_inverted_env
    assert_equal false, e.invert?
    i = e.invert
    
    assert_equal false, e.invert?
    assert_equal true, i.invert?
  end
  
  #
  # scan test
  #
  
  def test_scan_scans_the_specified_paths_to_discover_constants
    path = method_root.prepare(:tmp, 'a') do |io|
      io.puts "# A::resource"
      io.puts "# B::resource"
      io.puts "# B::alt"
    end
    
    e.scan(:tmp, "*")
    
    assert_equal ["A", "B"], e.constants.collect {|const| const.const_name }
    assert_equal [["resource"], ["resource", "alt"]], e.constants.collect {|const| const.types.keys }
  end
  
  def test_scan_adds_new_constants_and_amends_existing_constants
    path = method_root.prepare(:lib, 'a.rb') do |io|
      io.puts "# A::resource"
      io.puts "# C::resource"
    end
    
    assert_equal ["A", "C"], e.constants.collect {|const| const.const_name }
    assert_equal [["resource"], ["resource"]], e.constants.collect {|const| const.types.keys }
    
    path = method_root.prepare(:tmp, 'b') do |io|
      io.puts "# B::resource"
      io.puts "# C::alt"
    end
    
    e.scan(:tmp, "*")
    
    assert_equal ["A", "B", "C"], e.constants.collect {|const| const.const_name }
    assert_equal [["resource"], ["resource"], ["resource", "alt"]], e.constants.collect {|const| const.types.keys }
  end
  
  # def test_scan_raises_error_if_no_const_name_can_be_determined
  #   path = method_root.prepare(:tmp, 'a') do |io|
  #     io.puts "# ::resource"
  #   end
  #   
  #   assert_equal nil, Lazydoc[path].default_const_name
  #   err = assert_raises(RuntimeError) { e.scan(path) }
  #   assert_equal "could not determine a constant name for resource in: #{path.inspect}", err.message
  # end
  
  #
  # register test
  #
  
  module SampleConstant
  end
  
  def test_register_adds_a_Constant_for_the_input_constant_to_the_constants_cache_for_self
    assert_equal({}, e.constants.cache)
    const = e.register(SampleConstant)
    
    assert_equal "EnvTest::SampleConstant", const.const_name
    assert_equal({e => [const]}, e.constants.cache)
  end
  
  def test_register_preserves_alphabetical_order_in_entries
    a = Env::Constant.new("A")
    z = Env::Constant.new("Z")
    
    e.constants.cache[e] = [a, z]
    const = e.register(SampleConstant)
    assert_equal({e => [a, const, z]}, e.constants.cache)
  end
  
  def test_register_returns_the_constant_already_registered_to_self
    existing = Env::Constant.new("EnvTest::SampleConstant")
    e.constants.cache[e] = [existing]
    assert_equal existing.object_id, e.register(SampleConstant).object_id
  end
  
  def test_register_does_not_check_nested_environments_for_an_existing_constant
    a = Env.new(method_root[:a])
    b = Env.new(method_root[:b])
    a << b
    
    existing = Env::Constant.new("EnvTest::SampleConstant")
    a.constants.cache[b] = [existing].extend(Env::Minimap)
    
    assert_equal existing, a.constants.seek('sample_constant')
    const = a.register(SampleConstant)
    assert existing.object_id != const.object_id
    assert_equal const, a.constants.seek('sample_constant')
  end
  
  #
  # manifest.summarize test
  #
  
  def test_summarize_for_manifest
    e1 = Env.new method_root['a']
    e2 = Env.new method_root['b']
    e1.push e2
    
    m = e1.manifest do |env|
      case env
      when e1 then ["a/one.txt", "a/two.txt"]
      when e2 then ["b/one.txt", "b/three.txt"]
      end
    end
    
    template = %Q{<%= env_key %>:
<% minimap.each do |key, value| %>
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
}, "\n" + m.summarize(template)
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
    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @e = Env.new
  end
  
  def teardown
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
  
  def test_activate_freezes_const_paths
    assert !e.const_paths.frozen?
    e.activate
    assert e.const_paths.frozen?
  end
  
  def test_activate_unshifts_const_paths_to_LOAD_PATH
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
  
    e.activate
    
    assert_equal [e.root["/path/to/lib"], e.root["/path/to/another/lib"]], $LOAD_PATH
  end
  
  def test_activate_prioritizes_const_paths_in_LOAD_PATH
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["post", e.root["/path/to/another/lib"], e.root["/path/to/lib"]]
    
    e.activate
    
    assert_equal [e.root["/path/to/lib"], e.root["/path/to/another/lib"], "post"], $LOAD_PATH
  end
  
  def test_activate_does_not_add_const_paths_unless_specified
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    
    e.set_const_paths = false
    e.activate
    
    assert_equal [], $LOAD_PATH
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
  
  def test_deactivate_unfreezes_const_paths
    e.activate
    assert e.const_paths.frozen?
    
    e.deactivate
    assert !e.const_paths.frozen?
  end
  
  def test_deactivate_removes_const_paths_from_LOAD_PATH
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat [e.root["/path/to/lib"], e.root["/path/to/another/lib"]]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    e.deactivate
    
    assert_equal ["pre", "post"], $LOAD_PATH
  end
  
  def test_deactivate_does_not_remove_const_paths_unless_deactivated
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    $LOAD_PATH.clear
    $LOAD_PATH.concat ["/path/to/lib", "/path/to/another/lib"]
    
    assert !e.active?
    assert !e.deactivate
    assert_equal ["/path/to/lib", "/path/to/another/lib"], $LOAD_PATH
  end
  
  def test_deactivate_does_not_remove_const_paths_unless_specified
    e.const_paths = ["/path/to/lib", "/path/to/another/lib"]
    e.set_const_paths = false
    e.activate
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat [e.root["/path/to/lib"], e.root["/path/to/another/lib"]]
    $LOAD_PATH.unshift "pre"
    $LOAD_PATH.push "post"
    
    e.deactivate
    
    assert_equal ["pre", e.root["/path/to/lib"], e.root["/path/to/another/lib"], "post"], $LOAD_PATH
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
    e1.const_paths = ["/path/to/e1"]
    e.push e1
    
    e2 = Env.new
    e2.const_paths = ["/path/to/e2"]
    e1.push e2
    
    e3 = Env.new
    e3.const_paths = ["/path/to/e3"]
    e.push e3
    
    e.const_paths = ["/path/to/e"]
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
    e1.const_paths = ["/path/to/e1"]
    e.push e1
    
    e2 = Env.new
    e2.const_paths = ["/path/to/e2"]
    e1.push e2
    e2.push e
    
    e.const_paths = ["/path/to/e"]
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
  
  def test_const_paths_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.const_paths = [] }
    assert_equal "const_paths cannot be modified once active", err.message
  end
  
  def test_set_const_paths_cannot_be_set_once_active
    e.activate
    err = assert_raises(RuntimeError) { e.set_const_paths = false }
    assert_equal "set_const_paths cannot be modified once active", err.message
  end
end