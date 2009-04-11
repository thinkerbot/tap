require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/support/joins'

class SequenceTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  #
  # sequence tests
  #
  
  def test_simple_sequence
    runlist = []
    t0, t1 = Tracer.intern(2, runlist)
    
    t0.sequence(t1)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], app._results(t1))
  end
  
  def test_stack_sequence
    runlist = []
    t0, t1 = Tracer.intern(2, runlist)
    
    t0.sequence(t1, :stack => true)
    t0.enq ""
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0, '0'],[t1, '0 1']]
    ], app._results(t1))
  end
  
  def test_iterate_sequence
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist)
  
    t0.sequence(t1, :iterate => true)
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
        1
    }, runlist

    assert_audits_equal([
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t1, 'a 0 1']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t1, 'b 0 1']]
    ], app._results(t1))
  end
  
  def test_splat_sequence
    runlist = []
    t0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1 = Tracer.new(1, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end 
    
    t0.sequence(t1, :splat => true)
    t0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0 1
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    
    assert_audits_equal([
      [[m0a, m0b], [t1, ['a 0 1', 'b 0 1']]]
    ], app._results(t1))
  end
end