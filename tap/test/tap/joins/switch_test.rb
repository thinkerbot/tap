require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/joins/switch'
require 'tap/test/tracer'

class SwitchTest < Test::Unit::TestCase
  Switch = Tap::Joins::Switch
  
  attr_reader :app, :results, :runlist
  
  def setup
    @app = Tap::App.new
    tracer = app.use(Tap::Test::Tracer)
    
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  #
  # switch test
  #
  
  def test_simple_switch
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    
    index = nil
    app.join([a,b], [c,d], {}, Switch) do |result|
      index
    end
    
    # pick c
    index = 0
    a.enq
    e.enq
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
    b.enq
    e.enq
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
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    
    index = nil
    app.join([a,b], [c,d], {:enq => true}, Switch) do |result|
      index
    end
    
    # pick c
    index = 0
    a.enq
    e.enq
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
    b.enq
    e.enq
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
    a = app.node { ['a0', 'a1'] }
    b = app.node { ['b0', 'b1'] }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    
    index = nil
    app.join([a,b], [c,d], {:iterate => true}, Switch) do |result|
      index
    end
    
    # pick c
    index = 0
    a.enq
    e.enq
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
    b.enq
    e.enq
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
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| flunk "should not have executed" }
    e = app.node { 'd' }
    
    app.join([a,b], [c], {}, Switch) do |result|
      3
    end

    a.enq
    e.enq
    
    app.debug = true
    err = assert_raises(Tap::Joins::Switch::SwitchError) { app.run }
    assert_equal "no switch target at index: 3", err.message
    
    assert_equal [
      a,
    ], runlist
    
    assert_equal [
      [e, []]
    ], app.queue.to_a
  end
end
