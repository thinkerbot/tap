require File.join(File.dirname(__FILE__), '../../app_test_helper')
require 'tap/joins'

class MergeTest < Test::Unit::TestCase
  include JoinTestMethods
  
  #
  # merge tests
  #
  
  def test_simple_merge
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    
    t2.merge(t0, t1)
    app.enq t0, ''
    app.enq t1, ''
    app.run
  
    assert_equal %w{
      0 2
      1 2
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], results[t2]
  end
  
  def test_stack_merge
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    
    t2.merge(t0, t1, :stack => true)
    app.enq t0, ''
    app.enq t1, ''
    app.run
  
    assert_equal %w{
      0 1
      2 2
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], results[t2]
  end
  
  def test_iterate_splat_merge
    t0 = array(0)
    t1 = array(1)
    t2 = single(2)
  
    t2.merge(t0, t1, :iterate => true, :splat => true)
    app.enq t0, ['a', 'b']
    app.enq t1, ['c', 'd']
    app.run
  
    assert_equal %w{
      0 2
        2
      1 2
        2
    }, runlist

    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t2, 'c 1 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t2, 'd 1 2']]
    ], results[t2]
  end
  
  def test_splat_merge
    t0 = array(0)
    t1 = array(1)
    t2 = splat(2)
    
    t2.merge(t0, t1, :splat => true)
    app.enq t0, ['a', 'b']
    app.enq t1, ['a', 'b']
    app.run
  
    assert_equal %w{
      0 2
      1 2
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [0, "a 1"]]
    m1b = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [1, "b 1"]]
    
    assert_equal [
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]],
      [[m1a, m1b], [t2, ['a 1 2', 'b 1 2']]]
    ], results[t2]
  end
  
end