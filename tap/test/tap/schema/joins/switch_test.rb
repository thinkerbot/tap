require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/schema/joins'

class SwitchTest < Test::Unit::TestCase
  include JoinTestMethods
  
  def test_simple_switch
    t0, t1, t2 = single_tracers(0,1,2)
    
    index = nil
    t0.switch(t1, t2) do |_results|
      index
    end
    
    # pick t1
    index = 0
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    assert_equal nil, results[t2]
    
    # pick t2
    index = 1
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
      0 2
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], results[t2]
  end
  
  def test_stack_switch
    t0, t1, t2 = single_tracers(0,1,2)
    
    index = nil
    t0.switch(t1, t2, :stack => true) do |_results|
      index
    end
    
    # pick t1
    index = 0
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 
      1
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    assert_equal nil, results[t2]
    
    # pick t2
    index = 1
    t0.enq ""
    app.run
  
    assert_equal %w{
      0
      1
      0
      2
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], results[t2]
  end
  
  def test_iterate_switch
    t0 = *multi_tracers(0)
    t1, t2 = single_tracers(1,2)
    
    index = nil
    t0.switch(t1, t2, :iterate => true) do |_results|
      index
    end
    
    # pick t1
    index = 0
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], results[t1]
    assert_equal nil, results[t2]
    
    # pick t2
    index = 1
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
      0 2
        2
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], results[t1]
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']]
    ], results[t2]
  end
  
  def test_splat_switch
    t0 = *multi_tracers(0)
    t1, t2 = splat_tracers(1,2)
    
    index = nil
    t0.switch(t1, t2, :splat => true) do |_results|
      index
    end
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    
    # pick t1
    index = 0
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], results[t1]
    assert_equal nil, results[t2]
    
    # pick t2
    index = 1
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
      0 2
    }, runlist
    
    assert_equal nil, results[t0]
    assert_equal [
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], results[t1]
    assert_equal [
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]]
    ], results[t2]
  end
  
  def test_switch_raises_error_for_out_of_bounds_index
    t0, t1, t2 = single_tracers(0,1,2)
    t0.switch(t1, t2) do |_results|
      100
    end
  
    t0.enq ''
    assert_raises(RuntimeError) { app.run }
  end
end
