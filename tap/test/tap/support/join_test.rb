require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/join'

class JoinTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  attr_accessor :join
  
  def setup
    super
    @join = Join.new
  end
  
  #
  # join tests
  #
  
  def test_simple_join
    runlist = []
    t0, t1, t2, t3 = Tracer.intern(4, runlist)

    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 2 3
      1 2 3
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], app._results(t2))
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t3, '0 3']], 
      [[nil, ''],[t1, '1'],[t3, '1 3']],
    ], app._results(t3))
  end
  
  def test_stack_join
    runlist = []
    t0, t1, t2, t3 = Tracer.intern(4, runlist)
    
    join.stack = true
    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 1
      2 3
      2 3
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], app._results(t2))
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t3, '0 3']], 
      [[nil, ''],[t1, '1'],[t3, '1 3']],
    ], app._results(t3))
  end
  
  def test_iterate_join
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t2 = Tracer.new(2, runlist)
    t3 = Tracer.new(3, runlist)
    
    join.iterate = true
    join.join([t0,t1], [t2,t3])
    t0.enq ['a', 'b']
    t1.enq ['c', 'd']
    app.run
  
    assert_equal %w{
      0 2
        2
        3
        3
      1 2
        2
        3
        3
    }, runlist
  
    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t2, 'c 1 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t2, 'd 1 2']]
    ], app._results(t2))
    
    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t3, 'a 0 3']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t3, 'b 0 3']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t3, 'c 1 3']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t3, 'd 1 3']]
    ], app._results(t3))
  end
  
  def test_splat_join
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
    t3 = Tracer.new(3, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end
    
    join.splat = true
    join.join([t0,t1], [t2,t3])
    
    t0.enq(['a', 'b'])
    t1.enq(['a', 'b'])
    app.run
  
    assert_equal %w{
      0 2 3
      1 2 3
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [0, "a 1"]]
    m1b = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [1, "b 1"]]
    
    assert_audits_equal([
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]],
      [[m1a, m1b], [t2, ['a 1 2', 'b 1 2']]]
    ], app._results(t2))
    
    assert_audits_equal([
      [[m0a, m0b], [t3, ['a 0 3', 'b 0 3']]],
      [[m1a, m1b], [t3, ['a 1 3', 'b 1 3']]]
    ], app._results(t3))
  end
  
  def test_aggregate_join
    runlist = []
    t0, t1, t2, t3 = Tracer.intern(4, runlist)
    
    join.aggregate = true
    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 1
      2 3
    }, runlist
    
    m0 = [[nil, ''],[t0, '0']]
    m1 = [[nil, ''],[t1, '1']]
    
    assert_audits_equal([
      [[m0, m1], [:aggregate, ["0", "1"]], [t2, '01 2']]
    ], app._results(t2))
    
    assert_audits_equal([
      [[m0, m1], [:aggregate, ["0", "1"]], [t3, '01 3']]
    ], app._results(t3))
  end
end