require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/join'
require 'tap/test/tracer'

class JoinTest < Test::Unit::TestCase
  acts_as_tap_test
  Join = Tap::Join
  
  attr_reader :results, :runlist
  
  def setup
    super
    tracer = app.use(Tap::Test::Tracer)
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  def node(&node)
    def node.joins; @joins ||= []; end
    node
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
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    Join.new.join([a,b], [c,d])
    
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
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    Join.new(:enq => true).join([a,b], [c,d])
    
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
    a = node {|input| %w{a0 a1} }
    b = node {|input| %w{b0 b1} }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    Join.new(:iterate => true).join([a,b], [c,d])
    
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
  
  def test_join_removes_self_from_existing_inputs_on_join
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    
    join = Join.new({}, app)
    join.join([a], [])
    assert_equal [join], a.joins
    assert_equal [], b.joins
    
    join.join([b], [])
    assert_equal [], a.joins
    assert_equal [join], b.joins
  end
end