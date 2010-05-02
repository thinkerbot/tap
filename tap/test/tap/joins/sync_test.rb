require File.expand_path('../../../test_helper', __FILE__)
require 'tap/joins/sync'
require 'tap/test/tracer'
require 'tap/declarations'

class SyncTest < Test::Unit::TestCase
  acts_as_tap_test
  Sync = Tap::Joins::Sync
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
  # sync tests
  #
  
  def test_simple_sync
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| input.collect {|obj| "#{obj}.c" } }
    d = node {|input| input.collect {|obj| "#{obj}.d" } }
    e = node {|input| 'd' }
    Sync.new.join([a,b], [c,d])
    
    app.enq a
    app.enq b
    app.enq e
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
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| input.collect {|obj| "#{obj}.c" } }
    d = node {|input| input.collect {|obj| "#{obj}.d" } }
    e = node {|input| 'd' }
    Sync.new(:enq => true).join([a,b], [c,d])
    
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
    ], runlist
    
    assert_equal [
      ['a.c', 'b.c'],
    ], results[c]
    
    assert_equal [
      ['a.d', 'b.d'],
    ], results[d]
  end
  
  def test_iterate_sync
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| "#{input}.c" }
    d = node {|input| "#{input}.d" }
    e = node {|input| 'd' }
    Sync.new(:iterate => true).join([a,b], [c,d])
    
    app.enq a
    app.enq b
    app.enq e
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
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| flunk "should not have executed" }
    e = node {|input| 'd' }
    Sync.new.join([a,b], [c])
    
    app.enq a
    app.enq a
    app.enq e
    
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
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    
    join = Sync.new({}, app)
    join.join([a], [])
    assert_equal [join], a.joins.collect {|j| j.join }
    assert_equal [], b.joins.collect {|j| j.join }
    
    join.join([b], [])
    assert_equal [], a.joins.collect {|j| j.join }
    assert_equal [join], b.joins.collect {|j| j.join }
  end
end