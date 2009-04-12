require File.join(File.dirname(__FILE__), '../../app_test_helper')
require 'tap/joins'

class ForkTest < Test::Unit::TestCase
  include JoinTestMethods
  
  #
  # fork tests
  #
  
  def test_simple_fork
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    
    t0.fork(t1, t2)
    app.enq t0, ""
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], results[t2]
  end
  
  def test_stack_fork
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    
    t0.fork(t1, t2, :stack => true)
    app.enq t0, ""
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], results[t2]
  end
  
  def test_iterate_fork
    t0 = array(0)
    t1 = single(1)
    t2 = single(2)
    
    t0.fork(t1, t2, :iterate => true)
    app.enq t0, ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
        2
        2
    }, runlist

    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], results[t1]
    
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']]
    ], results[t2]
  end
  
  def test_splat_fork
    t0 = array(0)
    t1 = splat(1)
    t2 = splat(2)
    
    t0.fork(t1, t2, :splat => true)
    app.enq t0, ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    
    assert_equal [
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], results[t1]
    
    assert_equal [
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]]
    ], results[t2]
  end
end