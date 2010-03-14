require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/join'
require 'tap/test/tracer'

class JoinTest < Test::Unit::TestCase
  Join = Tap::Join
  Tracer = Tap::Test::Tracer
  
  attr_reader :app, :results, :runlist
  
  def setup
    @app = Tap::App.new
    tracer = app.use(Tracer)
    
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  #
  # parse test
  #
  
  def test_parse_initializes_with_config_specified_by_modifier
    join, args = Join.parse([])
    assert_equal false, join.iterate
    
    join, args = Join.parse("-i")
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
    
    a.enq
    b.enq
    e.enq
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
    
    a.enq
    b.enq
    e.enq
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
    
    a.enq
    b.enq
    e.enq
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