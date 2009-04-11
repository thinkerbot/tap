require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/support/joins'

class MergeTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  #
  # merge tests
  #
  
  def test_simple_merge
    runlist = []
    t0, t1, t2 = Tracer.intern(3, runlist)

    t2.merge(t0, t1)
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 2
      1 2
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], app._results(t2))
  end
  
  def test_stack_merge
    runlist = []
    t0, t1, t2 = Tracer.intern(3, runlist)

    t2.merge(t0, t1, :stack => true)
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 1
      2 2
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], app._results(t2))
  end
  
  def test_iterate_merge
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t2 = Tracer.new(2, runlist)
  
    t2.merge(t0, t1, :iterate => true)
    t0.enq ['a', 'b']
    t1.enq ['c', 'd']
    app.run
  
    assert_equal %w{
      0 2
        2
      1 2
        2
    }, runlist

    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t2, 'c 1 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t2, 'd 1 2']]
    ], app._results(t2))
  end
  
  def test_splat_merge
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end 
    t2 = Tracer.new(2, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end
    
    t2.merge(t0, t1, :splat => true)
    t0.enq(['a', 'b'])
    t1.enq(['a', 'b'])
    app.run
  
    assert_equal %w{
      0 2
      1 2
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [0, "a 1"]]
    m1b = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [1, "b 1"]]
    
    assert_audits_equal([
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]],
      [[m1a, m1b], [t2, ['a 1 2', 'b 1 2']]]
    ], app._results(t2))
  end
  
end