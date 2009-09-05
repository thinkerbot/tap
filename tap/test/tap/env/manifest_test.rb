require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/manifest'

class ManifestTest < Test::Unit::TestCase
  Manifest = Tap::Env::Manifest
  Minimap = Tap::Env::Minimap
  
  #
  # COMPOUND_KEY test
  #
  
  def test_COMPOUND_KEY_regexp
    r = Manifest::COMPOUND_KEY
    
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
  # setup
  #
  
  # A mock Env providing the necessary API, which is really just minimap
  class MockEnv
    include Minimap
    
    attr_reader :path, :envs
    
    def initialize(path)
      @path = path
      @envs = []
    end
    
    def each
      yield(self)
      envs.each {|e| yield(e) }
    end
  end
  
  attr_reader :e1, :e2, :e3
  
  def setup
    @e1 = MockEnv.new("/path/to/a")
    @e2 = MockEnv.new("/path/to/b")
    @e3 = MockEnv.new("/path/to/c")
  end
  
  #
  # intern test
  #
  
  def test_intern_initializes_manifest_with_block_as_builder
    block = lambda {}
    m = Manifest.intern(e1, &block)
    
    assert_equal e1, m.env
    assert_equal block, m.builder
  end
  
  #
  # initialize test
  #
  
  def test_initialize_ensures_each_cache_value_is_a_minimap
    array = []
    assert !array.kind_of?(Minimap)
    
    m = Manifest.new(e1, lambda {}, :a => array)
    assert array.kind_of?(Minimap)
  end
  
  #
  # build test
  #
  
  def test_build_builds_cache_for_each_in_env
    e1.envs.concat [e2, e3] 
    
    m = Manifest.intern(e1) {|e| [e.path] }
    assert m.cache.empty?
    m.build
    
    assert_equal({
      e1 => ["/path/to/a"],
      e2 => ["/path/to/b"],
      e3 => ["/path/to/c"]
    }, m.cache)
  end
  
  #
  # entries test
  #
  
  def test_entries_builds_cache_for_env
    m = Manifest.intern(e1) {|e| [e.path] }
    
    assert_equal ["/path/to/a"], m.entries(e1)
    assert_equal ["/path/to/b"], m.entries(e2)
    
    assert_equal({
      e1 => ["/path/to/a"],
      e2 => ["/path/to/b"]
    }, m.cache)
  end
  
  def test_entries_returns_cached_resources_if_they_exist
    m = Manifest.intern(e1, e1 => ["expected"]) {|e| ["error"] }
    assert_equal ["expected"], m.entries(e1)
  end
  
  def test_entries_extends_result_with_minimap
    array = []
    m = Manifest.intern(e1) {|e| array }
    
    assert !array.kind_of?(Minimap)
    assert_equal array.object_id, m.entries(e1).object_id
    assert array.kind_of?(Minimap)
  end
  
  #
  # each test
  #
  
  def test_each_yields_each_entry_for_each_env
    e1.envs << e2
    m = Manifest.intern(e1, 
      e1 => ["/a/one", "/a/two"], 
      e2 => ["/b/one", "/b/three"]
    )
    
    entries = []
    m.each {|entry| entries << entry }
    assert_equal ["/a/one", "/a/two", "/b/one", "/b/three"], entries
  end
  
  #
  # seek test
  #
  
  def test_seek_traverses_env_entries_for_first_matching_entry
    e1.envs << e2
    m = Manifest.intern(e1, 
      e1 => ["/path/to/a/one.txt", "/path/to/a/two.txt"], 
      e2 => ["/path/to/b/one.txt", "/path/to/b/three.txt"]
    )
    
    assert_equal "/path/to/a/one.txt", m.seek("one")
    assert_equal "/path/to/a/two.txt", m.seek("two")
    assert_equal "/path/to/b/three.txt", m.seek("three")
    
    assert_equal nil, m.seek("a:three")
    assert_equal "/path/to/a/one.txt", m.seek("a:one")
    assert_equal "/path/to/b/one.txt", m.seek("b:one")
    assert_equal nil, m.seek("b:two")
    assert_equal nil, m.seek("c:one")
    assert_equal nil, m.seek("four")
  end
  
  def test_seek_with_versions
    e1.envs << e2
    m = Manifest.intern(e1) do |env|
      [ "/path/to/one-0.1.0.txt",
        "/path/to/two.txt",
        "/path/to/another/one.txt",
        "/path/to/one-0.2.0.txt", 
      ].collect do |entry|
        "/#{File.basename(env.path)}#{entry}"
      end
    end
    
    # simple search of e1
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("to/one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("/path/to/one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("a/path/to/one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("/a/path/to/one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("one-0.1.0")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("one-0.1.0.txt")
    
    assert_equal "/a/path/to/two.txt", m.seek("two")
    assert_equal "/a/path/to/another/one.txt", m.seek("another/one")
    assert_equal "/a/path/to/one-0.2.0.txt", m.seek("one-0.2.0")
    
    # check e1 searches e2
    assert_equal "/b/path/to/one-0.1.0.txt", m.seek("/b/path/to/one")
    assert_equal "/b/path/to/one-0.1.0.txt", m.seek("/b/path/to/one-0.1.0")
    assert_equal "/b/path/to/one-0.1.0.txt", m.seek("/b/path/to/one-0.1.0.txt")
    
    # check with env pattern
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("a:one")
    assert_equal "/a/path/to/one-0.1.0.txt", m.seek("/path/to/a:one")
  
    assert_equal "/b/path/to/one-0.1.0.txt", m.seek("b:one")
    assert_equal "/b/path/to/one-0.1.0.txt", m.seek("/path/to/b:to/one")
    
    # a variety of nil cases
    assert_nil m.seek("c:one")
    assert_nil m.seek("another/path/to/a:one")
    assert_nil m.seek("/another/path/to/one")
    assert_nil m.seek("/path/to")
    assert_nil m.seek("non_existant")
  end
  
  def test_seek_only_builds_entries_as_necessary
    e1.envs << e2
    m = Manifest.intern(e1) {|env| [env.path]}
    
    assert_equal "/path/to/a", m.seek("a")
    assert_equal({
      e1 => ["/path/to/a"]
    }, m.cache)
    
    assert_equal "/path/to/b", m.seek("b")
    assert_equal({
      e1 => ["/path/to/a"],
      e2 => ["/path/to/b"]
    }, m.cache)
  end
  
  def test_seek_yields_each_match_to_block_until_block_return_true
    e1.envs << e2
    m = Manifest.intern(e1) {|env| ["/#{File.basename(env.path)}/path"]}
    
    assert_equal "/a/path", m.seek("path")
    assert_equal "/b/path", m.seek("path") {|path| path =~ /b/}
  end
  
  def test_seek_also_returns_the_env_if_env_also_is_true
    e1.envs << e2
    m = Manifest.intern(e1) {|env| [env.path]}
    
    assert_equal [e1, "/path/to/a"], m.seek("a", true)
    assert_equal [e2, "/path/to/b"], m.seek("b", true)
  end
  
  #
  # unseek test
  #
  
  def test_unseek_returns_key_for_entry_where_block_returns_true
    e1.envs << e2
    m = Manifest.intern(e1) do |env|
      [ "/path/to/one-0.1.0.txt",
        "/path/to/two.txt",
        "/path/to/another/one.txt",
        "/path/to/one-0.2.0.txt", 
      ].collect do |entry|
        "/#{File.basename(env.path)}#{entry}"
      end
    end
    
    assert_equal "one-0.1.0", m.unseek {|path| path =~ /one/ }
    assert_equal "two", m.unseek {|path| path =~ /two/ }
    assert_equal "another/one", m.unseek {|path| path =~ /another/ }
    assert_equal "one-0.2.0", m.unseek {|path| File.basename(path) == "one-0.2.0.txt" }
    
    assert_equal nil, m.unseek {|path| false }
  end
  
  def test_unseek_adds_env_key_if_specified
    e1.envs << e2
    m = Manifest.intern(e1) do |env|
      [ "/path/to/one-0.1.0.txt",
        "/path/to/two.txt",
        "/path/to/another/one.txt",
        "/path/to/one-0.2.0.txt", 
      ].collect do |entry|
        "/#{File.basename(env.path)}#{entry}"
      end
    end
    
    assert_equal "a:one-0.1.0", m.unseek(true) {|path| path == "/a/path/to/one-0.1.0.txt" }
    assert_equal "b:one-0.1.0", m.unseek(true) {|path| path == "/b/path/to/one-0.1.0.txt" }
  end
  
  def test_unseek_visits_entries_in_order
    e1.envs << e2
    m = Manifest.intern(e1, 
      e1 => ["/a/one", "/a/two"], 
      e2 => ["/b/one", "/b/three"]
    )
    
    entries = []
    m.unseek {|entry| entries << entry; false }
    assert_equal ["/a/one", "/a/two", "/b/one", "/b/three"], entries
  end
end