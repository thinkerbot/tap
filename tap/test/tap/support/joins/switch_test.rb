require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/support/joins'

class SwitchTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  def test_simple_switch
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, runlist)
    
    index = nil
    t0_0.switch(t1_0, t2_0) do |_results|
      index
    end
    
    # pick t1_0
    index = 0
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t2_0).empty?
    
    # pick t2_0
    index = 1
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.0 2.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.0 2.0
      0.0
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0']]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_batch_switch
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj

    index = nil
    t0_0.switch(t1_0, t2_0) do |_results|
      index
    end
    
    # pick t1
    index = 0
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0 1.0
          1.1
      0.1 1.0
          1.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert app._results(t0_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert app._results(t2_0).empty?
    assert app._results(t2_1).empty?
    
    # pick t2
    index = 1
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0 1.0
          1.1
      0.1 1.0
          1.1
      0.0 2.0
          2.1
      0.1 2.0
          2.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert app._results(t0_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      [[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']],
      [[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']]
    ], app._results(t2_1))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0 1.0
          1.1
      0.1 1.0
          1.1
      0.0 2.0
          2.1
      0.1 2.0
          2.1
      0.0
      0.1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0']]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      [[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']],
      [[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']]
    ], app._results(t2_1))
  end
  
  def test_stack_switch
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, runlist)
    
    index = nil
    t0_0.switch(t1_0, t2_0, :stack => true) do |_results|
      index
    end
    
    # pick t1_0
    index = 0
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 
      1.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t2_0).empty?
    
    # pick t2_0
    index = 1
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 
      1.0
      0.0 
      2.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 
      1.0
      0.0 
      2.0
      0.0
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0']]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_batched_stack_switch
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj

    index = nil
    t0_0.switch(t1_0, t2_0, :stack => true) do |_results|
      index
    end
    
    # pick t1
    index = 0
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0      0.1
      1.0 1.1  1.0 1.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert app._results(t0_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert app._results(t2_0).empty?
    assert app._results(t2_1).empty?
    
    # pick t2
    index = 1
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0      0.1
      1.0 1.1  1.0 1.1
      0.0      0.1
      2.0 2.1  2.0 2.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert app._results(t0_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      [[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']],
      [[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']]
    ], app._results(t2_1))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ''
    app.run
    
    assert_equal %w{
      0.0      0.1
      1.0 1.1  1.0 1.1
      0.0      0.1
      2.0 2.1  2.0 2.1
      0.0
      0.1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0']]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      [[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']],
      [[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']]
    ], app._results(t1_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      [[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']],
      [[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']]
    ], app._results(t2_1))
  end
  
  def test_iterate_switch
    runlist = []
    t0_0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1_0 = Tracer.new(1, runlist)
    t2_0 = Tracer.new(2, runlist)
    
    index = nil
    t0_0.switch(t1_0, t2_0, :iterate => true) do |_results|
      index
    end
    
    # pick t1_0
    index = 0
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t1_0, 'a 0.0 1.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t1_0, 'b 0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t2_0).empty?
    
    # pick t2_0
    index = 1
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
      0.0 2.0
          2.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t1_0, 'a 0.0 1.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t1_0, 'b 0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t2_0, 'a 0.0 2.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t2_0, 'b 0.0 2.0']]
    ], app._results(t2_0))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
      0.0 2.0
          2.0
      0.0
    }, runlist
    
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']]]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t1_0, 'a 0.0 1.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t1_0, 'b 0.0 1.0']]
    ], app._results(t1_0))
    assert_audits_equal([
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[0, 'a 0.0'],[t2_0, 'a 0.0 2.0']],
      [[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[1, 'b 0.0'],[t2_0, 'b 0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_splat_switch
    runlist = []
    t0_0 = Tracer.new(0, runlist) do |task, input|
      input.collect {|str| task.mark(str) }
    end
    t1_0 = Tracer.new(1, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end 
    t2_0 = Tracer.new(2, runlist) do |task, *inputs|
      inputs.collect {|str| task.mark(str) }
    end
    
    index = nil
    t0_0.switch(t1_0, t2_0, :splat => true) do |_results|
      index
    end
    
    m0_0a = [[nil, ["a", "b"]], [t0_0, ["a 0.0", "b 0.0"]], [0, "a 0.0"]]
    m0_0b = [[nil, ["a", "b"]], [t0_0, ["a 0.0", "b 0.0"]], [1, "b 0.0"]]
    
    # pick t1_0
    index = 0
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[m0_0a, m0_0b], [t1_0, ['a 0.0 1.0', 'b 0.0 1.0']]]
    ], app._results(t1_0))
    assert app._results(t2_0).empty?
    
    # pick t2_0
    index = 1
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.0 2.0
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[m0_0a, m0_0b], [t1_0, ['a 0.0 1.0', 'b 0.0 1.0']]]
    ], app._results(t1_0))
    assert_audits_equal([
      [[m0_0a, m0_0b], [t2_0, ['a 0.0 2.0', 'b 0.0 2.0']]]
    ], app._results(t2_0))
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.0 2.0
      0.0
    }, runlist
    
    assert_audits_equal([
      [[nil, ["a", "b"]], [t0_0, ["a 0.0", "b 0.0"]]]
    ], app._results(t0_0))
    assert_audits_equal([
      [[m0_0a, m0_0b], [t1_0, ['a 0.0 1.0', 'b 0.0 1.0']]]
    ], app._results(t1_0))
    assert_audits_equal([
      [[m0_0a, m0_0b], [t2_0, ['a 0.0 2.0', 'b 0.0 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_unbatched_switch
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj

    index = nil
    t0_0.switch(t1_0, t2_0, :unbatched => true) do |_results|
      index
    end
    
    # pick t1_0
    index = 0
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t1_1).empty?
    assert app._results(t2_0).empty?
    assert app._results(t2_1).empty?
    
    # pick t2_0
    index = 1
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.1
      0.0 2.0
      0.1
    }, runlist
    
    assert app._results(t0_0).empty?
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']],
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t1_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
    assert app._results(t2_1).empty?
    
    # now skip (aggregate result)
    index = nil
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
      0.1
      0.0 2.0
      0.1
      0.0
      0.1
    }, runlist
    
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0']]
    ], app._results(t0_0))
    assert_audits_equal([
      [[nil, ''],[t0_1, '0.1']],
      [[nil, ''],[t0_1, '0.1']],
      [[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    assert app._results(t1_1).empty?
    assert_audits_equal([
      [[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
    assert app._results(t2_1).empty?
  end
  
  def test_switch_raises_error_for_out_of_bounds_index
    t0_0, t1_0, t2_0 = Tracer.intern(3, [])
    t0_0.switch(t1_0, t2_0) do |_results|
      100
    end
  
    t0_0.enq ''
    assert_raise(RuntimeError) { app.run }
  end
end
