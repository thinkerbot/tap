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
    t0_0, t1_0 = Tracer.intern(2, runlist)
    
    t0_0.sequence(t1_0)
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
  end
  
  def test_batch_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    
    t0_0.sequence(t1_0)
    t0_0.enq ''
    app.run
  
    assert_equal %w{
      0.0 1.0 
          1.1
      0.1 1.0 
          1.1
    }, runlist
      
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
      
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']], 
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']], 
    ], app._results(t1_1))
  end
  
  def test_stack_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, runlist)
    
    t0_0.sequence(t1_0, :stack => true)
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
  end
  
  def test_batched_stack_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    
    t0_0.sequence(t1_0, :stack => true)
    t0_0.enq ''
    app.run
  
    assert_equal %w{
      0.0      0.1
      1.0 1.1  1.0 1.1
    }, runlist
      
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
      
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']], 
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']], 
    ], app._results(t1_1))
  end
  
  def test_iterate_sequence
    runlist = []
    t0_0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1_0 = Tracer.new(1, runlist)
  
    t0_0.sequence(t1_0, :iterate => true)
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
    }, runlist

    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t1_0, 'a 0.0 1.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t1_0, 'b 0.0 1.0']]
    ], app._results(t1_0))
  end
  
  def test_splat_sequence
    runlist = []
    t0_0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1_0 = Tracer.new(1, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end 
    
    t0_0.sequence(t1_0, :splat => true)
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    m0_0a = [[nil, ["a", "b"]], [t0_0, ["a 0.0", "b 0.0"]], [0, "a 0.0"]]
    m0_0b = [[nil, ["a", "b"]], [t0_0, ["a 0.0", "b 0.0"]], [1, "b 0.0"]]
    
    assert_audits_equal([
      [[m0_0a, m0_0b], [t1_0, ['a 0.0 1.0', 'b 0.0 1.0']]]
    ], app._results(t1_0))
  end
  
  def test_unbatched_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    
    t0_0.sequence(t1_0, :unbatched => true)
    assert_equal nil, t0_1.on_complete_block
    assert_equal nil, t1_1.on_complete_block

    t0_0.enq ''
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    
    assert app._results(t1_1).empty?
  end
end