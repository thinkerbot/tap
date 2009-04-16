require File.join(File.dirname(__FILE__), '../../app_test_helper')
require 'tap/joins'

class SyncMergeTest < Test::Unit::TestCase
  include JoinTestMethods
  
  #
  # sync_merge tests
  #
  
  def test_simple_sync_merge
    t0 = single(0)
    t1 = single(1)
    t2 = splat(2)
    
    t2.sync_merge(t0, t1)
    app.enq t0, ''
    app.enq t1, ''
    app.run
  
    assert_equal %w{
      0
      1 2
    }, runlist
    
    m0 = [[nil, ''],[t0, '0']]
    m1 = [[nil, ''],[t1, '1']]

    assert_equal [
      [[m0,m1], [t2,['0 2', '1 2']]]
    ], results[t2]
  end
  
  def test_stack_sync_merge
    t0 = single(0)
    t1 = single(1)
    t2 = splat(2)
    
    t2.sync_merge(t0, t1, :mode => :enq)
    app.enq t0, ''
    app.enq t1, ''
    app.run
  
    assert_equal %w{
      0
      1 2
    }, runlist
    
    m0 = [[nil,''],[t0,'0']]
    m1 = [[nil,''],[t1,'1']]
  
    assert_equal [
      [[m0,m1], [t2,['0 2', '1 2']]]
    ], results[t2]
  end
  
  def test_iterate_sync_merge
    t0 = array(0)
    t1 = array(1)
    t2 = single(2)
    
    t2.sync_merge(t0, t1, :modifier => :iterate)
    app.enq t0, ['a','b']
    app.enq t1, ['x','y']
    app.run
  
    assert_equal %w{
      0
      1 
        2
        2
        2
        2
    }, runlist
    
    assert_equal [
      [[nil, ['a','b']],[t0, ['a 0', 'b 0']], [0, 'a 0'], [t2,'a 0 2']],
      [[nil, ['a','b']],[t0, ['a 0', 'b 0']], [1, 'b 0'], [t2,'b 0 2']],
      [[nil, ['x','y']],[t1, ['x 1', 'y 1']], [0, 'x 1'], [t2,'x 1 2']],
      [[nil, ['x','y']],[t1, ['x 1', 'y 1']], [1, 'y 1'], [t2,'y 1 2']],
    ], results[t2]
  end
  
  def test_splat_sync_merge
    t0 = array(0)
    t1 = array(1)
    t2 = splat(2)
    
    t2.sync_merge(t0, t1, :modifier => :splat)
    app.enq t0, ['a', 'b']
    app.enq t1, ['a', 'b']
    app.run
  
    assert_equal %w{
      0
      1
        2
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [0, "a 1"]]
    m1b = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [1, "b 1"]]
    
    assert_equal [
      [[m0a, m0b, m1a, m1b], [t2, ['a 0 2', 'b 0 2', 'a 1 2', 'b 1 2']]],
    ], results[t2]
  end
  
  def test_sync_merge_raises_error_if_target_cannot_be_enqued_before_a_source_executes_twice
    t0 = single(0)
    t1 = single(1)
    t2 = splat(2)
    
    t2.sync_merge(t0, t1, :mode => :enq)
    app.enq t0, ''
    app.enq t0, ''
    app.enq t1, ''
    
    assert_raises(RuntimeError) { app.run }
    assert_equal %w{
      0
      0
    }, runlist
  end
end