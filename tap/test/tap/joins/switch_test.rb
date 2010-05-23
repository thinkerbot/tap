require File.expand_path('../../../test_helper', __FILE__)
require 'tap/joins/switch'
require 'tap/test/tracer'
require 'tap/declarations'

class SwitchTest < Test::Unit::TestCase
  acts_as_tap_test
  Switch = Tap::Joins::Switch
  include Tap::Declarations
  
  attr_reader :results, :runlist
  
  def setup
    super
    tracer = app.use(Tap::Test::Tracer)
    @results = tracer.results
    @runlist = tracer.runlist
    initialize_declare
  end
  
  #
  # switch test
  #
  
  def test_simple_switch
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    
    index = nil
    Switch.new.join([a,b], [c,d]) {|result| index }
    
    # pick c
    index = 0
    app.enq a
    app.enq e
    app.run
  
    assert_equal [
      a, c,
      e,
    ], runlist
    
    assert_equal [
      'a.c'
    ], results[c]
    
    assert_equal nil, results[d]
    
    # pick d
    index = 1
    app.enq b
    app.enq e
    app.run
  
    assert_equal [
      a, c,
      e,
      b, d,
      e,
    ], runlist
    
    assert_equal [
      'a.c'
    ], results[c]
    
    assert_equal [
      'b.d'
    ], results[d]
  end
  
  def test_enq_switch
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    
    index = nil
    Switch.new(:enq => true).join([a,b], [c,d]) {|result| index }
    
    # pick c
    index = 0
    app.enq a
    app.enq e
    app.run
  
    assert_equal [
      a,
      e,
      c,
    ], runlist
    
    assert_equal [
      'a.c'
    ], results[c]
    
    assert_equal nil, results[d]
    
    # pick d
    index = 1
    app.enq b
    app.enq e
    app.run
  
    assert_equal [
      a,
      e,
      c,
      b,
      e,
      d,
    ], runlist
    
    assert_equal [
      'a.c'
    ], results[c]
    
    assert_equal [
      'b.d'
    ], results[d]
  end
  
  def test_iterate_switch
    a = node {|input| ['a0', 'a1'] }
    b = node {|input| ['b0', 'b1'] }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    
    index = nil
    Switch.new(:iterate => true).join([a,b], [c,d]) {|result| index }
    
    # pick c
    index = 0
    app.enq a
    app.enq e
    app.run
  
    assert_equal [
      a, c, c,
      e,
    ], runlist
    
    assert_equal [
      'a0.c', 
      'a1.c'
    ], results[c]
    
    assert_equal nil, results[d]
    
    # pick d
    index = 1
    app.enq b
    app.enq e
    app.run
  
    assert_equal [
      a, c, c,
      e,
      b, d, d,
      e,
    ], runlist
    
    assert_equal [
      'a0.c', 
      'a1.c'
    ], results[c]
    
    assert_equal [
      'b0.d', 
      'b1.d'
    ], results[d]
  end
  
  def test_switch_raises_error_for_out_of_bounds_index
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| flunk "should not have executed" }
    e = node {|input| 'd' }
    
    Switch.new.join([a,b], [c]) {|result| 3}
    
    app.enq a
    app.enq e
    
    app.debug = true
    err = assert_raises(Tap::Joins::Switch::SwitchError) { app.run }
    assert_equal "no switch target at index: 3", err.message
    
    assert_equal [
      a,
    ], runlist
    
    assert_equal [e, []], app.queue.deq
  end
end
