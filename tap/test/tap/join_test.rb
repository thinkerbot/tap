require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/join'
require 'tap/app/tracer'

class JoinTest < Test::Unit::TestCase
  Join = Tap::Join
  
  attr_reader :app, :results, :runlist
  
  def setup
    @app = Tap::App.new
    tracer = app.use(Tap::App::Tracer)
    
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  #
  # parse test
  #
  
  def test_parse_initializes_with_config_specified_by_modifier
    join = Join.parse([])
    assert_equal false, join.iterate
    
    join = Join.parse("-i")
    assert_equal true, join.iterate
  end
  
  #
  # join tests
  #
  
  def test_simple_join
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    app.join([a,b], [c,d])
    
    app.enq a
    app.enq b
    app.enq e
    app.run
  
    assert_equal [
      a, c, d,
      b, c, d,
      e,
    ], runlist
    
    assert_equal [
      'a.c', 
      'b.c'
    ], results[c]
    
    assert_equal [
      'a.d', 
      'b.d'
    ], results[d]
  end
  
  def test_enq_join
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], :enq => true)
    
    app.enq a
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, 
      b,
      e,
      c,
      d,
      c, 
      d,
    ], runlist
    
    assert_equal [
      'a.c', 
      'b.c'
    ], results[c]
    
    assert_equal [
      'a.d', 
      'b.d'
    ], results[d]
  end
  
  def test_iterate_join
    a = app.node { %w{a0 a1} }
    b = app.node { %w{b0 b1} }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], :iterate => true)
    
    app.enq a
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, c, c, d, d,
      b, c, c, d, d,
      e,
    ], runlist

    assert_equal [
      'a0.c',
      'a1.c',
      'b0.c', 
      'b1.c',
    ], results[c]
    
    assert_equal [
      'a0.d',
      'a1.d',
      'b0.d',
      'b1.d',
    ], results[d]
  end
  
  def test_splat_join
    a = app.node { %w{a0 a1} }
    b = app.node { %w{b0 b1} }
    c = app.node {|*inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|*inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], :splat => true)
    
    app.enq a
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, c, d,
      b, c, d,
      e,
    ], runlist

    assert_equal [
      ['a0.c', 'a1.c'],
      ['b0.c', 'b1.c'],
    ], results[c]
    
    assert_equal [
      ['a0.d', 'a1.d'],
      ['b0.d', 'b1.d'],
    ], results[d]
  end
  
  def test_iterate_splat_join
    a = app.node { [%w{a0 a1}, "a2"] }
    b = app.node { [%w{b0 b1}, "b2"] }
    c = app.node {|*inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|*inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], :iterate => true, :splat => true)
    
    app.enq a
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, c, c, d, d,
      b, c, c, d, d,
      e,
    ], runlist

    assert_equal [
      ['a0.c', 'a1.c'],
      ['a2.c'],
      ['b0.c', 'b1.c'],
      ['b2.c'],
    ], results[c]
    
    assert_equal [
      ['a0.d', 'a1.d'],
      ['a2.d'],
      ['b0.d', 'b1.d'],
      ['b2.d'],
    ], results[d]
  end
  
  def test_join_removes_self_from_existing_inputs_on_join
    a = app.node { 'a' }
    b = app.node { 'b' }
    
    join = Join.new({}, app)
    join.join([a], [])
    assert_equal [join], a.joins
    assert_equal [], b.joins
    
    join.join([b], [])
    assert_equal [], a.joins
    assert_equal [join], b.joins
  end
end