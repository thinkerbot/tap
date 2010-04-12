require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/joins/gate'
require 'tap/test/tracer'
 
class GateTest < Test::Unit::TestCase
  acts_as_tap_test
  Join = Tap::Join
  Gate = Tap::Joins::Gate
  
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
  # join test
  #
  
  def test_gate_join_enques_self_after_call_when_results_are_nil
    assert_equal [], app.queue.to_a
    
    join = Gate.new({}, app)
    join.join([], [])
    
    assert_equal nil, join.results
    join.call('a')
    
    assert_equal [
      [join, ['a']]
    ], app.queue.to_a
    
    assert join.results != nil
    join.call('b')
    
    assert_equal [
      [join, ['a', 'b']]
    ], app.queue.to_a
    
    # resets join results
    join.call(join.results)
    
    assert_equal nil, join.results
    join.call('c')
    
    assert_equal [
      [join, ['a', 'b']],
      [join, ['c']]
    ], app.queue.to_a
  end
  
  def test_gate_join_collects_results_on_each_call
    join = Gate.new({}, app)
    join.call('a')
    join.call('b')
    join.call('c')
    
    assert_equal ['a', 'b', 'c'], join.results
  end
  
  def test_gate_join_executes_results_when_called_with_results
    was_in_block = false
    node = node do |input|
      assert_equal ['a', 'b', 'c'], input
      was_in_block = true
    end
    
    join = Gate.new({}, app)
    join.call('a')
    join.call('b')
    join.call('c')
    join.join([], [node])
    
    assert_equal false, was_in_block
    join.call(join.results)
    
    assert_equal true, was_in_block
    assert_equal nil, join.results
  end
  
  def test_simple_gate
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| input.collect {|obj| "#{obj}.c" } }
    d = node {|input| input.collect {|obj| "#{obj}.d" } }
    e = node {|input| 'd' }
    join = Gate.new.join([a,b], [c,d])
    
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
  
  def test_gate_with_limit
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| input.collect {|obj| "#{obj}.c" } }
    d = node {|input| input.collect {|obj| "#{obj}.d" } }
    e = node {|input| 'd' }
    join = Gate.new(:limit => 2).join([a,b], [c,d])
    
    app.enq a
    app.enq a
    app.enq a
    app.enq b
    app.enq b
    app.enq e
    app.run
    
    assert_equal [
      a, a, c, d,
      a, b, c, d,
      b,
      e,
      join,
      c, d
    ], runlist
    
    assert_equal [
      ["a.c", "a.c"], 
      ["a.c", "b.c"], 
      ["b.c"]
    ], results[c]
    
    assert_equal [
      ["a.d", "a.d"], 
      ["a.d", "b.d"], 
      ["b.d"]
    ], results[d]
  end
  
  def test_gate_from_execute_workflow
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| 'c' }
    d = node {|input| 'd' }
    e = node {|input| 'e' }
    f = node {|input| 'f' }
    g = node {|input| input.collect {|obj| "#{obj}.g" } }
    
    Join.new.join([b], [c])
    Join.new.join([c], [d,e])
    join = Gate.new.join([a,d,e,f], [g])
    
    app.enq a
    app.enq b
    app.enq f
    app.run
    
    assert_equal [
      a, b, c, d, e, f,
      join, g
    ], runlist
    
    assert_equal [
      ["a.g", "d.g", "e.g", "f.g"]
    ], results[g]
  end
  
  def test_gate_from_enque_workflow
    a = node {|input| 'a' }
    b = node {|input| 'b' }
    c = node {|input| 'c' }
    d = node {|input| 'd' }
    e = node {|input| 'e' }
    f = node {|input| 'f' }
    g = node {|input| input.collect {|obj| "#{obj}.g" } }
    
    Join.new(:enq => true).join([b], [d])
    Join.new(:enq => true).join([d], [e,f])
    join = Gate.new(:enq => true).join([a,c,e,f], [g])
    
    app.enq a
    app.enq b
    app.enq c
    app.run
    
    assert_equal [
      a, b, c,
      join, 
      d, 
      g, 
      e, f,
      join,
      g
    ], runlist
    
    assert_equal [
      ["a.g", "c.g"],
      ["e.g", "f.g"]
    ], results[g]
  end
end