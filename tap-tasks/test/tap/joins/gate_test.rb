require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/joins/gate'
require 'tap/app/tracer'

class GateDocumentationTest < Test::Unit::TestCase 
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  def test_gate_documentation
      sh_test %Q{
% tap run -- load a -- load b -- inspect --[0,1][2].gate
["a", "b"]
}
      sh_test %Q{
% tap run -- load/yaml "[1, 2, 3]" --:i inspect --:.gate inspect
1
2
3
[1, 2, 3]
}

      sh_test %Q{
% tap run -- load/yaml "[1, 2, 3]" --:i inspect --:.sync inspect
1
[1]
2
[2]
3
[3]
}

      sh_test %Q{
% tap run -- load/yaml "[1, 2, 3]" --:i inspect --:"gate --limit 2" inspect
1
2
[1, 2]
3
[3]
}
  end
end

class GateTest < Test::Unit::TestCase
  Gate = Tap::Joins::Gate
  
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
  
  def test_gate_join_enques_self_after_call_when_results_are_nil
    assert_equal [], app.queue.to_a
    
    join = Gate.new({}, app)
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
  
  def test_gate_join_gate_results_on_each_call
    join = Gate.new({}, app)
    join.call('a')
    join.call('b')
    join.call('c')
    
    assert_equal ['a', 'b', 'c'], join.results
  end
  
  def test_gate_join_dispatches_results_when_called_with_results
    was_in_block = false
    node = app.node do |inputs|
      assert_equal ['a', 'b', 'c'], inputs
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
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], {}, Gate)
    
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
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node {|inputs| inputs.collect {|input| "#{input}.c" } }
    d = app.node {|inputs| inputs.collect {|input| "#{input}.d" } }
    e = app.node { 'd' }
    join = app.join([a,b], [c,d], {:limit => 2}, Gate)
    
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
  
  def test_gate_from_imperative_workflow
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node { 'c' }
    d = app.node { 'd' }
    e = app.node { 'e' }
    f = app.node { 'f' }
    g = app.node {|inputs| inputs.collect {|input| "#{input}.g" } }
    
    app.join([b], [c])
    app.join([c], [d,e])
    join = app.join([a,d,e,f], [g], {}, Gate)
    
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
    a = app.node { 'a' }
    b = app.node { 'b' }
    c = app.node { 'c' }
    d = app.node { 'd' }
    e = app.node { 'e' }
    f = app.node { 'f' }
    g = app.node {|inputs| inputs.collect {|input| "#{input}.g" } }
    
    app.join([b], [d], :enq => true)
    app.join([d], [e,f], :enq => true)
    join = app.join([a,c,e,f], [g], {:enq => true}, Gate)
    
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