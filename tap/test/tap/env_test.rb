require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'
require 'rubygems'

class EnvTest < Test::Unit::TestCase
  include Tap::Env::Utils
  Env = Tap::Env
  
  attr_reader :e, :method_root
  
  def setup
    @e = Env.new
    @method_root = Tap::Root.new("#{__FILE__.chomp(".rb")}_#{method_name}")
  end
  
  def teardown
    # clear out the output folder if it exists, unless flagged otherwise
    unless ENV["KEEP_OUTPUTS"]
      FileUtils.rm_r(method_root.root) if File.exists?(method_root.root)
    end
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    e = Env.new
    assert_equal Dir.pwd, e.root.root
    assert_equal [], e.envs
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
      File.expand_path("path/to/dir")
    ], e.envs.collect {|env| env.root.root } 
  end
  
  def test_set_env_paths_loads_string_inputs_as_yaml
    e.env_paths = "[one, two]"
    assert_equal [
      File.expand_path("one"),
      File.expand_path("two")
    ], e.envs.collect {|env| env.root.root }
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
  # manifest.seek test
  #
  
  def test_seek_for_manifest
    a_one = method_root.prepare("a/one.txt") {|io| io << "::one"}
    a_two = method_root.prepare("a/two.txt") {|io| io << "::two"}
    b_one = method_root.prepare("b/one.txt") {|io| io << "::one"}
    b_three = method_root.prepare("b/three.txt") {|io| io << "::three"}
    
    e1 = Env.new(method_root['a'])
    e2 = Env.new(method_root['b'])
    e1.push e2
    
    m = e1.manifest do |env|
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
    
    m = e1.manifest(:items) do |env|
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

end