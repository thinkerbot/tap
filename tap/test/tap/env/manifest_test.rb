require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/manifest'
require 'tap/root'

class ManifestTest < Test::Unit::TestCase
  Manifest = Tap::Env::Manifest
  
  attr_reader :m, :e
  
  class MockEnv
    attr_reader :root, :envs
    def initialize(dir=Dir.pwd)
      @root = Tap::Root.new(dir)
      @envs = []
    end
  end
  
  def setup
    @e = MockEnv.new
    builder = lambda { [] }
    @m = Manifest.new(e, builder)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    b = lambda {}
    m = Manifest.new e, b
    assert_equal e, m.env
    assert_equal nil, m.entries(false)
    assert_equal b, m.builder
    assert_equal({}, m.cache)
    assert !m.built?
  end
  
  #
  # build test
  #
  
  def test_build_sets_entries_to_builder_result
    builder = lambda { :result }
    m = Manifest.new(e, builder) 
    assert_equal nil, m.entries(false)
    m.build
    assert_equal :result, m.entries(false)
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