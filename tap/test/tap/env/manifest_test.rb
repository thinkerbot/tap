require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/manifest'
require 'tap/env'

class ManifestTest < Test::Unit::TestCase
  Env = Tap::Env
  Manifest = Tap::Env::Manifest
  
  attr_reader :env, :m
  
  def setup
    @env = Env.new
    @m = Manifest.new(env, :type)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    env = Env.new :registry => {:type => [1,2,3]}
    m = Manifest.new(env, :type)
    assert_equal :type, m.type
    assert_equal env, m.env
    assert_equal [1,2,3], m.entries(false)
    assert !m.built?
  end
  
  #
  # build test
  #
  
  def test_build_sets_built
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

  #
  # entries test
  #
  
  def test_entries_are_the_env_objects_for_type
    objects = [1,2,3]
    env = Env.new :registry => {:type => objects}
    m = Manifest.new(env, :type)
    assert_equal objects.object_id, m.entries.object_id
  end
  
  #
  # empty? test
  #
  
  def test_empty_builds_self
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
    e1 = Env.new :registry => {:type => %w{a/b/c}}
    e2 = Env.new :registry => {:type => %w{a/b/d}}
    e3 = Env.new :registry => {:type => %w{a/b/e}}
    e1.envs = [e2, e3]
    
    m = Manifest.new(e1, :type)
    
    envs = []
    e1.each {|e| envs << e }
    assert_equal [e1, e2, e3], envs
    
    assert_equal "a/b/c", m.seek("c")
    assert_equal "a/b/d", m.seek("d")
    assert_equal "a/b/e", m.seek("e")
    assert_equal nil, m.seek("f")
  end
  
  def test_seek_selects_env_by_compound_key
    e1 = Env.new :root => 'one', :registry => {:type => %w{a/b/c}}
    e2 = Env.new :root => 'two', :registry => {:type => %w{a/b/d}}
    e3 = Env.new :root => 'three', :registry => {:type => %w{a/b/e}}
    e1.envs = [e2, e3]
    
    m = Manifest.new(e1, :type)
    
    assert_equal "a/b/c", m.seek("one:c")
    assert_equal "a/b/d", m.seek("two:d")
    assert_equal "a/b/e", m.seek("three:e")
    
    assert_equal nil, m.seek("one:d")
    assert_equal nil, m.seek("two:c")
    assert_equal nil, m.seek("nil:e")
  end
  
  #
  # another test
  #
  
  def test_another_makes_a_new_instance_of_self_assigned_to_env
    alt = Env.new
    another = m.another(alt)
    assert_equal m.class, another.class
    assert_equal alt, another.env
    assert !another.built?
    
    assert m.entries.object_id != another.entries.object_id
  end
  
  class Another < Manifest
  end
  
  def test_another_instantiates_the_same_class_as_self
    m = Another.new(Env.new, :type)
    assert_equal Another, m.another(Env.new).class
  end
end