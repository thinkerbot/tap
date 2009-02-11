require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/support/joins'

class ForkTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  #
  # fork tests
  #
  
  def test_simple_fork
    runlist = []
    t0, t1, t2 = Tracer.intern(3, runlist)
    
    t0.fork(t1, t2)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], app._results(t1))
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], app._results(t2))
  end
  
  def test_stack_fork
    runlist = []
    t0, t1, t2 = Tracer.intern(3, runlist)
    
    t0.fork(t1, t2, :stack => true)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], app._results(t1))
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t2, '0 2']]
    ], app._results(t2))
  end
  
  def test_iterate_fork
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end

    t1 = Tracer.new(1, runlist)
    t2 = Tracer.new(2, runlist)
  
    t0.fork(t1, t2, :iterate => true)
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
        2
        2
    }, runlist

    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], app._results(t1))
    
    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']]
    ], app._results(t2))
  end
  
  def test_splat_fork
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end 
    t2 = Tracer.new(2, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end
    
    t0.fork(t1, t2, :splat => true)
    t0.enq(['a', 'b'])
    app.run
  
    assert_equal %w{
      0 1
        2
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    
    assert_audits_equal([
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], app._results(t1))
    
    assert_audits_equal([
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]]
    ], app._results(t2))
  end
  
end