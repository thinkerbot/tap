require File.join(File.dirname(__FILE__), '../../../app_test_helper')
require 'tap/app/joins'

class SequenceTest < Test::Unit::TestCase
  include JoinTestMethods
  
  #
  # sequence tests
  #
  
  def test_simple_sequence
    t0, t1 = single_tracers(0,1)
    
    t0.sequence(t1)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
  end
  
  def test_stack_sequence
    t0, t1 = single_tracers(0,1)
    
    t0.sequence(t1, :stack => true)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], results[t1]
  end
  
  def test_iterate_sequence
    t0 = *multi_tracers(0)
    t1 = *single_tracers(1)
  
    t0.sequence(t1, :iterate => true)
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
    }, runlist

    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], results[t1]
  end
  
  def test_splat_sequence
    t0 = *multi_tracers(0)
    t1 = *splat_tracers(1)
    
    t0.sequence(t1, :splat => true)
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    
    assert_equal [
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], results[t1]
  end
end