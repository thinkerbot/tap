require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/joins'

class SyncMergeTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  #
  # sync_merge tests
  #
  
  def test_simple_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.sync_merge(t0_0, t1_0)
    t0_0.enq ''
    t1_0.enq ''
    app.run
  
    assert_equal %w{
      0.0
      1.0 2.0
    }, runlist
    
    m0_0 = ExpAudit[[nil, ''],[t0_0, '0.0']]
    m1_0 = ExpAudit[[nil, ''],[t1_0, '1.0']]

    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['0.0 2.0', '1.0 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_batch_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.sync_merge(t0_0, t1_0)
    t0_0.enq ''
    t1_0.enq ''
    app.run
    
    assert_equal %w{
      0.0
      0.1
      1.0
          2.0 2.1
          2.0 2.1
      1.1 
          2.0 2.1
          2.0 2.1
    }, runlist
    
    m0_0 = ExpAudit[[nil, ''],[t0_0, '0.0']]
    m0_1 = ExpAudit[[nil, ''],[t0_1, '0.1']]
    m1_0 = ExpAudit[[nil, ''],[t1_0, '1.0']]
    m1_1 = ExpAudit[[nil, ''],[t1_1, '1.1']]
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['0.0 2.0', '1.0 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_0,['0.1 2.0', '1.0 2.0']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_0,['0.0 2.0', '1.1 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_0,['0.1 2.0', '1.1 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_1,['0.0 2.1', '1.0 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_1,['0.1 2.1', '1.0 2.1']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_1,['0.0 2.1', '1.1 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_1,['0.1 2.1', '1.1 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_stack_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ''
    t1_0.enq ''
    app.run
  
    assert_equal %w{
      0.0
      1.0 2.0
    }, runlist
    
    m0_0 = ExpAudit[[nil,''],[t0_0,'0.0']]
    m1_0 = ExpAudit[[nil,''],[t1_0,'1.0']]

    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['0.0 2.0', '1.0 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_stack_batch_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ''
    t1_0.enq ''
    app.run
    
    assert_equal %w{
      0.0
      0.1
      1.0
      1.1 
          2.0 2.1
          2.0 2.1
          2.0 2.1
          2.0 2.1
    }, runlist
    
    m0_0 = ExpAudit[[nil, ''],[t0_0, '0.0']]
    m0_1 = ExpAudit[[nil, ''],[t0_1, '0.1']]
    m1_0 = ExpAudit[[nil, ''],[t1_0, '1.0']]
    m1_1 = ExpAudit[[nil, ''],[t1_1, '1.1']]
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['0.0 2.0', '1.0 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_0,['0.1 2.0', '1.0 2.0']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_0,['0.0 2.0', '1.1 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_0,['0.1 2.0', '1.1 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_1,['0.0 2.1', '1.0 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_1,['0.1 2.1', '1.0 2.1']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_1,['0.0 2.1', '1.1 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_1,['0.1 2.1', '1.1 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_iterate_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
  
    t2_0.sync_merge(t0_0, t1_0, :iterate => true)
    t0_0.enq ''
    t1_0.enq ''
    app.run
  
    assert_equal %w{
      0.0
      1.0 
          2.0
          2.0
    }, runlist
    
    m0_0 = ExpAudit[[nil, ''],[t0_0, '0.0']]
    m1_0 = ExpAudit[[nil, ''],[t1_0, '1.0']]

    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [AuditIterate.new(0), '0.0'], [t2_0,'0.0 2.0']],
      ExpAudit[ExpMerge[m0_0,m1_0], [AuditIterate.new(1), '1.0'], [t2_0,'1.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_unbatched_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.sync_merge(t0_0, t1_0, :unbatched => true)
    assert_equal nil, t0_1.on_complete_block
    assert_equal nil, t1_1.on_complete_block
    assert_equal nil, t2_1.on_complete_block
    
    t0_0.enq ''
    t1_0.enq ''
    app.run
  
    assert_equal %w{
      0.0
      0.1
      1.0
          2.0
      1.1
    }, runlist
    
    m0_0 = ExpAudit[[nil, ''],[t0_0, '0.0']]
    m1_0 = ExpAudit[[nil, ''],[t1_0, '1.0']]

    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['0.0 2.0', '1.0 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t1_1, '1.1']]
    ], app._results(t1_1))
    
    assert app._results(t2_1).empty?
  end
  
  def test_sync_merge_raises_error_if_target_cannot_be_enqued_before_a_source_executes_twice
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
  
    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ''
    t0_0.enq ''
    t1_0.enq ''
    
    assert_raise(RuntimeError) { app.run }
    assert_equal %w{
      0.0
      0.0
    }, runlist
  end
end