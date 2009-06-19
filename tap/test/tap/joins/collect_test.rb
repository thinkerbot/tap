require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/joins'
require 'tap/app/tracer'

class CollectTest < Test::Unit::TestCase
  Collect = Tap::Joins::Collect
  
  attr_reader :app, :results, :runlist
  
  def setup
    @app = Tap::App.new
    tracer = app.use(Tap::App::Tracer)
    
    @results = tracer.results
    @runlist = tracer.runlist
  end
  
  #
  # join test
  #
  
  def test_collect_join_enques_self_after_call_when_results_are_nil
    assert_equal [], app.queue.to_a
    
    join = Collect.new({}, app)
    join.join([], [])
    
    assert_equal nil, join.results
    join.call('a')
    
    assert_equal [
      [join, [['a']]]
    ], app.queue.to_a
    
    assert join.results != nil
    join.call('b')
    
    assert_equal [
      [join, [['a', 'b']]]
    ], app.queue.to_a
    
    # resets join results
    join.call(join.results)
    
    assert_equal nil, join.results
    join.call('c')
    
    assert_equal [
      [join, [['a', 'b']]],
      [join, [['c']]]
    ], app.queue.to_a
  end
  
  def test_collect_join_collect_results_on_each_call
    join = Collect.new({}, app)
    join.call('a')
    join.call('b')
    join.call('c')
    
    assert_equal ['a', 'b', 'c'], join.results
  end
  
  def test_collect_join_dispatches_results_when_called_with_results
    was_in_block = false
    node = app.node do |inputs|
      assert_equal ['a', 'b', 'c'], inputs
      was_in_block = true
    end
    
    join = Collect.new({}, app)
    join.call('a')
    join.call('b')
    join.call('c')
    join.join([], [node])
    
    assert_equal false, was_in_block
    join.call(join.results)
    
    assert_equal true, was_in_block
    assert_equal nil, join.results
  end
  
  def test_simple_collect
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], {}, Collect)
    
    app.enq a
    app.enq a
    app.enq a
    app.enq b
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, a, a,
      b, b,
      e,
      join,
      c, d
    ], runlist
    
    assert_equal [
      ["a.c", "a.c", "a.c", "b.c", "b.c"]
    ], results[c]
    
    assert_equal [
      ["a.d", "a.d", "a.d", "b.d", "b.d"]
    ], results[d]
  end
end