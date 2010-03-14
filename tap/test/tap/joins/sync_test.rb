require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/joins/sync'
require 'tap/test/tracer'

class SyncTest < Test::Unit::TestCase
  Sync = Tap::Joins::Sync
  
  attr_reader :app, :results, :runlist
  
  def setup
    @app = Tap::App.new
    tracer = app.use(Tap::Test::Tracer)
    
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  #
  # sync tests
  #
  
  def test_simple_sync
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|*inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|*inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    app.join([a,b], [c,d], {}, Sync)
    
    a.enq
    b.enq
    e.enq
    app.run
  
    assert_equal [
      a, 
      b, c, d,
      e,
    ], runlist
    
    assert_equal [
      ['a.c', 'b.c'],
    ], results[c]
    
    assert_equal [
      ['a.d', 'b.d'],
    ], results[d]
  end
  
  def test_enq_sync
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|*inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|*inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    app.join([a,b], [c,d], {:enq => true}, Sync)
    
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
    ], runlist
    
    assert_equal [
      ['a.c', 'b.c'],
    ], results[c]
    
    assert_equal [
      ['a.d', 'b.d'],
    ], results[d]
  end
  
  def test_iterate_sync
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|input| "#{input}.c" }
    d = app.node {|input| "#{input}.d" }
    e = app.node { 'd' }
    app.join([a,b], [c,d], {:iterate => true}, Sync)
    
    a.enq
    b.enq
    e.enq
    app.run
  
    assert_equal [
      a, 
      b, c, c, d, d,
      e,
    ], runlist
    
    assert_equal [
      'a.c', 
      'b.c',
    ], results[c]
    
    assert_equal [
      'a.d', 
      'b.d',
    ], results[d]
  end
  
  def test_sync_merge_raises_error_if_target_cannot_be_enqued_before_a_source_executes_twice
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|*inputs| flunk "should not have executed" }
    e = app.node { 'd' }
    app.join([a,b], [c], {}, Sync)
    
    a.enq
    a.enq
    e.enq
    
    app.debug = true
    err = assert_raises(Tap::Joins::Sync::SynchronizeError) { app.run }
    assert_equal "already got a result for: #{a}", err.message
    
    assert_equal [
      a,
      a,
    ], runlist
    
    assert_equal [
      [e, []]
    ], app.queue.to_a
  end
  
  def test_sync_removes_callbacks_from_existing_inputs_on_join
    a = app.node { 'a' }
    b = app.node { 'b' }
    
    join = Sync.new({}, app)
    join.join([a], [])
    assert_equal [join], a.joins.collect {|j| j.join }
    assert_equal [], b.joins.collect {|j| j.join }
    
    join.join([b], [])
    assert_equal [], a.joins.collect {|j| j.join }
    assert_equal [join], b.joins.collect {|j| j.join }
  end
end