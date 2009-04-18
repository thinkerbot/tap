require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/manifest'

class ManifestTest < Test::Unit::TestCase
  Manifest = Tap::Env::Manifest
  
  attr_reader :env, :m
  
  class MockEnv
    attr_accessor :envs, :matches
    
    def initialize(envs=[], matches={})
      @envs = envs
      @matches = matches
    end
    
    def each
      yield(self)
      envs.each {|env| yield(env) }
    end
    
    def minimatch(key)
      @matches[key]
    end
  end
  
  def setup
    @env = MockEnv.new
    @m = Manifest.new(env)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    m = Manifest.new :env
    assert_equal :env, m.env
    assert_equal nil, m.entries(false)
    assert_equal({}, m.cache)
    assert !m.built?
  end
  
  #
  # build test
  #
  
  def test_build_sets_entries
    m = Manifest.new(:env) 
    assert_equal nil, m.entries(false)
    m.build
    assert_equal [], m.entries(false)
  end
  
  #
  # built? test
  #
  
  def test_built_returns_true_if_built
    assert !m.built?
    m.build
    assert m.built?
  end
  
  #
  # reset test
  #
  
  def test_reset_sets_built_to_false
    m.build
    assert m.built?
    m.reset
    assert !m.built?
  end
  
  def test_reset_sets_entries_to_nil
    m.build
    assert_equal [], m.entries(false)
    m.reset
    assert_equal nil, m.entries(false)
  end
  
  def test_reset_clears_cache
    m.cache[:key] = 'value'
    m.reset
    assert_equal({}, m.cache)
  end
  
  #
  # empty? test
  #
  
  def test_empty_builds_self_if_necessary
    assert !m.built?
    assert m.empty?
    assert m.built?
  end
  
  def test_empty_is_true_if_entries_are_empty
    assert m.entries.empty?
    assert m.empty?
    
    m.entries << :one
    assert !m.empty?
  end
  
  #
  # each test
  #
  
  def test_each_builds_self_if_necessary
    assert !m.built?
    m.each {|e| }
    assert m.built?
  end
  
  def test_each_iterates_over_each_entry_in_self
    m.entries.concat [:one, :two, :three]
    
    results = []
    m.each {|entry| results << entry}
    
    assert_equal [:one, :two, :three], results
  end
  
  #
  # seek test
  #
  
  def test_seek_returns_first_minimatching_entry
    m.entries.concat [
      "a/b/c",
      "a/b/d"
    ]
    
    assert_equal "a/b/c", m.seek("c")
    assert_equal "a/b/d", m.seek("d")
  end
  
  def test_seek_traverses_env_each_to_find_match
    e1, e2, e3 = Array.new(3) { MockEnv.new }
    e1.envs = [e2, e3]
    
    m1 = Manifest.new e1
    m1.entries.concat %w{a/b/c}
    
    m2 = Manifest.new e2
    m2.entries.concat %w{a/b/d}
    
    m3 = Manifest.new e3
    m3.entries.concat %w{a/b/e}
    
    m1.cache = {
      e1 => m1,
      e2 => m2,
      e3 => m3
    }
    
    envs = []
    e1.each {|e| envs << e }
    assert_equal [e1, e2, e3], envs
    
    assert_equal "a/b/c", m1.seek("c")
    assert_equal "a/b/d", m1.seek("d")
    assert_equal "a/b/e", m1.seek("e")
    assert_equal nil, m1.seek("f")
  end
  
  def test_seek_selects_env_by_compound_key
    e1, e2, e3 = Array.new(3) { MockEnv.new }
    e1.matches = {
      'one' => e1,
      'two' => e2,
      'three' => e3
    }
    
    m1 = Manifest.new e1
    m1.entries.concat %w{a/b/c}
    
    m2 = Manifest.new e2
    m2.entries.concat %w{a/b/d}
    
    m3 = Manifest.new e3
    m3.entries.concat %w{a/b/e}
    
    m1.cache = {
      e1 => m1,
      e2 => m2,
      e3 => m3
    }
    
    assert_equal "a/b/c", m1.seek("one:c")
    assert_equal "a/b/d", m1.seek("two:d")
    assert_equal "a/b/e", m1.seek("three:e")
    
    assert_equal nil, m1.seek("one:d")
    assert_equal nil, m1.seek("two:c")
    assert_equal nil, m1.seek("nil:e")
  end
  
  #
  # another test
  #
  
  def test_another_makes_a_new_instance_of_self_assigned_to_env
    another = m.another(:alt)
    assert_equal m.class, another.class
    assert_equal :alt, another.env
    assert !another.built?
    
    assert m.entries.object_id != another.entries.object_id
  end
  
  class Another < Manifest
  end
  
  def test_another_instantiates_the_same_class_as_self
    m = Another.new :env
    assert_equal Another, m.another(:alt).class
  end

  #
  # COMPOUND_REGEXP test
  #
  
  def test_COMPOUND_REGEXP_REGEXP
    r = Manifest::COMPOUND_REGEXP
    
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
end