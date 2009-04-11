require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/manifest'

class ManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :m
  
  def setup
    @m = Manifest.new([])
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    m = Manifest.new([])
    assert_equal [], m.entries
    assert !m.bound?
    assert m.built?
  end
  
  #
  # bind test
  #
  
  def test_bind_sets_env_and_reader
    mock_env = Object.new
    m.bind(mock_env, :object_id)
    assert_equal mock_env, m.env
    assert_equal :object_id, m.reader
  end
  
  def test_bind_returns_self
    assert_equal m, m.bind(Object.new, :object_id)
  end
  
  def test_bind_raises_error_if_env_is_nil
    assert_raises(ArgumentError) { m.bind(nil, :object_id) }
  end
  
  def test_bind_raises_error_if_env_does_not_respond_to_reader
    mock_env = Object.new
    assert !mock_env.respond_to?(:non_existant_reader)
    assert_raises(ArgumentError) { m.bind(mock_env, :non_existant_reader) }
  end
  
  #
  # unbind test
  #
  
  def test_unbind_sets_env_and_reader_to_nil
    m.bind(Object.new, :object_id)
    assert m.env != nil
    assert m.reader != nil
    
    m.unbind
    assert_equal nil, m.env
    assert_equal nil, m.reader
  end
  
  def test_unbind_returns_self
    assert_equal m, m.unbind
  end
  
  #
  # bound? test
  #
  
  def test_bind_sets_bound_to_true_and_unbind_sets_bound_to_false
    m.bind(Object.new, :object_id)
    assert m.bound?
    
    m.unbind
    assert !m.bound?
  end
  
  #
  # build test
  #
  
  def test_build_returns_self
    assert_equal m, m.build
  end
  
  #
  # built? test
  #
  
  def test_built_returns_true
    assert m.built?
  end
  
  #
  # reset test
  #
  
  def test_reset_returns_self
    assert_equal m, m.reset
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_entries_are_empty
    assert m.entries.empty?
    assert m.empty?
    
    m.entries << :one
    assert !m.empty?
  end
  
  #
  # each test
  #
  
  def test_each_iterates_over_each_entry_in_self
    m.entries.concat [:one, :two, :three]
    
    results = []
    m.each {|entry| results << entry}
    
    assert_equal [:one, :two, :three], results
  end
  
  #
  # [] test
  #
  
  def test_AGET_is_an_alias_of_minimatch
    m.entries << "/path/to/one"
    m.entries << "/path/to/another/one"
    m.entries << "/path/to/two"
    
    assert_equal "/path/to/one", m['one']
    assert_equal "/path/to/one", m['to/one']
    assert_equal "/path/to/another/one", m['another/one']
    assert_equal "/path/to/two", m['two']
    assert_equal nil, m['non_existant']
  end

  #
  # SEARCH_REGEXP test
  #
  
  def test_SEARCH_REGEXP_REGEXP
    r = Manifest::SEARCH_REGEXP
    
    # key only
    assert r =~ "key"
    assert_equal ["key", nil], [$1, $4]
    
    assert r =~ "path/to/key"
    assert_equal ["path/to/key", nil], [$1, $4]
    
    assert r =~ "/path/to/key"
    assert_equal ["/path/to/key", nil], [$1, $4]
    
    assert r =~ "C:/path/to/key"
    assert_equal ["C:/path/to/key", nil], [$1, $4]
    
    assert r =~ 'C:\path\to\key'
    assert_equal ['C:\path\to\key', nil], [$1, $4]
    
    # env_key and key
    assert r =~ "env_key:key"
    assert_equal ["env_key", "key"], [$1, $4]
    
    assert r =~ "path/to/env_key:path/to/key"
    assert_equal ["path/to/env_key", "path/to/key"], [$1, $4]
    
    assert r =~ "/path/to/env_key:/path/to/key"
    assert_equal ["/path/to/env_key", "/path/to/key"], [$1, $4]
    
    assert r =~ "C:/path/to/env_key:C:/path/to/key"
    assert_equal ["C:/path/to/env_key", "C:/path/to/key"], [$1, $4]
    
    assert r =~ 'C:\path\to\env_key:C:\path\to\key'
    assert_equal ['C:\path\to\env_key', 'C:\path\to\key'], [$1, $4]
    
    assert r =~ "/path/to/env_key:C:/path/to/key"
    assert_equal ["/path/to/env_key", "C:/path/to/key"], [$1, $4]
    
    assert r =~ "C:/path/to/env_key:/path/to/key"
    assert_equal ["C:/path/to/env_key", "/path/to/key"], [$1, $4]
  end
  
  #
  # search is tested in env_test
  #
end