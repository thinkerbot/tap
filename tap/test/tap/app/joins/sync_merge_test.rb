require File.join(File.dirname(__FILE__), '../../../app_test_helper')
require 'tap/app/joins'

class SyncMergeTest < Test::Unit::TestCase
  include JoinTestMethods
  
  #
  # sync_merge tests
  #
  
  def test_simple_sync_merge
    t0, t1 = single_tracers(0,1)
    t2 = *splat_tracers(2)
    
    t2.sync_merge(t0, t1)
    t0.enq ''
    t1.enq ''
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
    t0, t1 = single_tracers(0,1)
    t2 = *splat_tracers(2)
    
    t2.sync_merge(t0, t1, :stack => true)
    t0.enq ''
    t1.enq ''
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
    t0, t1 = multi_tracers(0,1)
    t2 = *single_tracers(2)
    
    t2.sync_merge(t0, t1, :iterate => true)
    t0.enq ['a','b']
    t1.enq ['x','y']
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
    t0, t1 = multi_tracers(0,1)
    t2 = *splat_tracers(2)
    
    t2.sync_merge(t0, t1, :splat => true)
    t0.enq(['a', 'b'])
    t1.enq(['a', 'b'])
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
    t0, t1 = single_tracers(0,1)
    t2 = *splat_tracers(2)
    
    t2.sync_merge(t0, t1, :stack => true)
    t0.enq ''
    t0.enq ''
    t1.enq ''
    
    assert_raises(RuntimeError) { app.run }
    assert_equal %w{
      0
      0
    }, runlist
  end
end