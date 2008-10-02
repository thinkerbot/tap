require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/joins'

class ForkTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_tap_test
  
  #
  # fork tests
  #
  
  def test_simple_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    
    t0_0.fork(t1_0, t2_0)
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
          2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_batch_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t0_0.fork(t1_0, t2_0)
    t0_0.enq ''
    app.run
  
    assert_equal %w{
      0.0 1.0 
          1.1
          2.0
          2.1
      0.1 1.0 
          1.1
          2.0
          2.1
    }, runlist
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']], 
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']], 
    ], app._results(t1_1))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']], 
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']], 
    ], app._results(t2_1))
  end
  
  def test_stack_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    
    t0_0.fork(t1_0, t2_0, :stack => true)
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
          2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_batched_stack_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t0_0.fork(t1_0, t2_0, :stack => true)
    t0_0.enq ''
    app.run
  
    assert_equal %w{
      0.0             0.1
      1.0 1.1 2.0 2.1 1.0 1.1 2.0 2.1
    }, runlist
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']],
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t1_0, '0.1 1.0']]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_1, '0.0 1.1']], 
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t1_1, '0.1 1.1']], 
    ], app._results(t1_1))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']],
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t2_0, '0.1 2.0']]
    ], app._results(t2_0))
      
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_1, '0.0 2.1']], 
      ExpAudit[[nil, ''],[t0_1, '0.1'],[t2_1, '0.1 2.1']], 
    ], app._results(t2_1))
  end
  
  def test_iterate_fork
    runlist = []
    t0_0, t1_0, t2_0= Tracer.intern(3, app, runlist)
  
    t0_0.fork(t1_0, t2_0, :iterate => true)
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
          2.0
          2.0
    }, runlist

    assert_audits_equal([
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditIterate.new(0), 'a 0.0'],[t1_0, 'a 0.0 1.0']],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditIterate.new(1), 'b 0.0'],[t1_0, 'b 0.0 1.0']]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditIterate.new(0), 'a 0.0'],[t2_0, 'a 0.0 2.0']],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditIterate.new(1), 'b 0.0'],[t2_0, 'b 0.0 2.0']]
    ], app._results(t2_0))
  end
  
  def test_unbatched_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t0_0.fork(t1_0, t2_0, :unbatched => true)
    assert_equal nil, t0_1.on_complete_block
    assert_equal nil, t1_1.on_complete_block
    assert_equal nil, t2_1.on_complete_block
    
    t0_0.enq ""
    app.run
  
    assert_equal %w{
      0.0 1.0
          2.0
      0.1 
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_1, '0.1']]
    ], app._results(t0_1))
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t1_0, '0.0 1.0']]
    ], app._results(t1_0))
    
    assert app._results(t1_1).empty?
    
    assert_audits_equal([
      ExpAudit[[nil, ''],[t0_0, '0.0'],[t2_0, '0.0 2.0']]
    ], app._results(t2_0))
    
    assert app._results(t2_1).empty?
  end
  
end