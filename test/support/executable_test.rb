require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable'

class ExecutableTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_tap_test
  
  attr_accessor :m
  
  def setup
    super
    @m = Executable.initialize(Object.new, :object_id, app)
  end
  
  #
  # initialization tests
  #
  
  def test_initialization_defaults
    m = Executable.initialize(Object.new, :object_id)
    assert m.kind_of?(Executable)
    assert_equal :object_id, m._method_name
    assert_equal Tap::App.instance, m.app
    assert_equal [m], m.batch
    assert_equal [], m.dependencies
    assert_nil m.on_complete_block
  end
  
  def test_initialize
    app = Tap::App.new
    m = Object.new
    b = lambda {}
    
    assert_equal m, Executable.initialize(m, :object_id, app, [1,2,3], [4,5,6], &b)
    assert m.kind_of?(Executable)
    assert_equal :object_id, m._method_name
    assert_equal app, m.app
    assert_equal [1,2,3,m], m.batch
    assert_equal [4,5,6], m.dependencies
    assert_equal b, m.on_complete_block
  end
  
  #
  # initialize_batch_obj test
  #
  
  def test_initialize_batch_obj_duplicates_self_and_adds_duplicate_to_batch
    b = lambda {}
    m = Executable.initialize(Object.new, :object_id, app, [1,2,3], [4,5,6], &b)

    m1 = m.initialize_batch_obj
    m2 = m1.initialize_batch_obj
    
    assert_equal :object_id, m._method_name
    assert_equal :object_id, m1._method_name
    assert_equal :object_id, m2._method_name
    
    assert_equal app, m.app
    assert_equal m.app.object_id, m1.app.object_id
    assert_equal m.app.object_id, m2.app.object_id
    
    assert_equal [4,5,6], m.dependencies
    assert_equal m.dependencies.object_id, m1.dependencies.object_id
    assert_equal m.dependencies.object_id, m2.dependencies.object_id
    
    assert_equal [1,2,3, m, m1, m2], m.batch
    assert_equal m.batch.object_id, m1.batch.object_id
    assert_equal m.batch.object_id, m2.batch.object_id
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
    assert_equal b, m2.on_complete_block
  end
  
  class SimpleExecutable
    include Tap::Support::Executable
    
    attr_reader :var
    
    def initialize(method_name, app, batch, dependencies, &on_complete_block)
      @_method_name = method_name
      @app = app
      @batch = batch
      @dependencies = dependencies
      @on_complete_block = on_complete_block
      
      batch << self
      
      # a variable to demonstrate duplication
      @var = Object.new
    end
  end
  
  def test_initialize_batch_obj_with_class_including_Executable_behaves_the_same
    b = lambda {}
    m = SimpleExecutable.new(:object_id, app, [1,2,3], [4,5,6], &b)

    m1 = m.initialize_batch_obj
    m2 = m1.initialize_batch_obj
    
    assert_equal m1.var, m.var
    assert_equal m2.var, m.var
    
    assert_equal :object_id, m._method_name
    assert_equal :object_id, m1._method_name
    assert_equal :object_id, m2._method_name
    
    assert_equal app, m.app
    assert_equal m.app.object_id, m1.app.object_id
    assert_equal m.app.object_id, m2.app.object_id
    
    assert_equal [4,5,6], m.dependencies
    assert_equal m.dependencies.object_id, m1.dependencies.object_id
    assert_equal m.dependencies.object_id, m2.dependencies.object_id
    
    assert_equal [1,2,3, m, m1, m2], m.batch
    assert_equal m.batch.object_id, m1.batch.object_id
    assert_equal m.batch.object_id, m2.batch.object_id
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
    assert_equal b, m2.on_complete_block
  end
  
  #
  # batched? test
  #
  
  def test_batched_returns_true_if_batch_size_is_greater_than_one
    assert !m.batched?
    assert_equal 1, m.batch.size
    
    m.initialize_batch_obj
    
    assert_equal 2, m.batch.size
    assert m.batched?
  end
  
  #
  # batch_index test
  #
  
  def test_batch_index_returns_the_index_of_the_task_in_batch
    assert_equal [m], m.batch
    assert_equal 0, m.batch_index
    
    m1 = m.initialize_batch_obj
    
    assert_equal [m, m1], m.batch
    assert_equal 1, m1.batch_index
  end
  
  #
  # batch_with test
  #
  
  class BatchExecutable
    include Tap::Support::Executable
    def initialize(batch=[])
      @batch = batch
      batch << self
    end
  end
  
  def test_batch_with_documentation
    b1 = BatchExecutable.new
    b2 = BatchExecutable.new
    b3 = BatchExecutable.new
  
    b1.batch_with(b2, b3)
    assert_equal [b1, b2, b3], b1.batch
    assert_equal [b1, b2, b3], b3.batch
  
    b4 = BatchExecutable.new
    b4.batch_with(b3)   
             
    assert_equal [b4, b1, b2, b3], b4.batch
    assert_equal [b4, b1, b2, b3], b3.batch
    assert_equal [b1, b2, b3], b2.batch
    assert_equal [b1, b2, b3], b1.batch
  
    b5 = BatchExecutable.new(b1.batch)
    b6 = BatchExecutable.new
  
    assert_equal b1.batch.object_id, b5.batch.object_id
    assert_equal [b1, b2, b3, b5], b5.batch
  
    b5.batch_with(b6)
  
    assert_equal [b1, b2, b3, b5, b6], b5.batch
    assert_equal [b1, b2, b3, b5, b6], b1.batch
  end
  
  def test_batch_with_merges_batches_of_each_input
    m1 = BatchExecutable.new
    m2 = BatchExecutable.new
    m3 = BatchExecutable.new
    
    m1.batch.clear
    m1.batch.concat [0,1]
    
    m2.batch.clear
    m2.batch.concat [2]
    
    m3.batch.clear
    m3.batch.concat [3,4]
    
    m1.batch_with(m2, m3)
    
    assert_equal m1.batch, m2.batch
    assert_equal m2.batch, m3.batch
    assert_equal [0,1,2,3,4], m1.batch
  end
  
  def test_batch_with_removes_duplicates
    m1 = BatchExecutable.new
    m2 = BatchExecutable.new
  
    m1.batch.clear
    m1.batch.concat [0,1]
    
    m2.batch.clear
    m2.batch.concat [1,2]
    
    m1.batch_with(m2)
    
    assert_equal m1.batch, m2.batch
    assert_equal [0,1,2], m1.batch
  end
  
  def test_batch_with_returns_self
    b = BatchExecutable.new
    assert_equal b, b.batch_with
  end
  
  def test_batch_with_self_does_nothing
    b = BatchExecutable.new
    assert_equal [b], b.batch
    b.batch_with(b)
    assert_equal [b], b.batch
  end
  
  #
  # enq test
  #
  
  def test_enq_enqueues_self_to_app_with_inputs
    assert app.queue.empty?
    
    m.enq 1
    
    assert_equal 1, app.queue.size
    assert_equal [[m, [1]]], app.queue.to_a
    
    m.enq 1
    m.enq 2
    
    assert_equal [[m, [1]], [m, [1]], [m, [2]]], app.queue.to_a
  end
  
  def test_enq_enqueues_batched_executables
    m1 = m.initialize_batch_obj
    
    assert app.queue.empty?
    assert_equal 2, m.batch.size
    
    m.enq 1
    
    assert_equal 2, app.queue.size
    assert_equal [[m, [1]], [m1, [1]]], app.queue.to_a
  end
  
  def test_enq_returns_self
    assert_equal m, m.enq
  end
  
  #
  # unbatched_enq test
  #
  
  def test_unbatched_enq_only_enqueues_self
    m1 = m.initialize_batch_obj
    
    assert_equal 2, m.batch.size
    assert app.queue.empty?
    m.unbatched_enq 1
    
    assert_equal 1, app.queue.size
    assert_equal [[m, [1]]], app.queue.to_a
  end
  
  def test_unbatched_enq_returns_self
    assert_equal m, m.unbatched_enq
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_sets_on_complete_block_for_all_executables_in_batch
    m1 = m.initialize_batch_obj
    
    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  
    b = lambda {}
    m.on_complete(&b)
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
  end
  
  def test_on_complete_raises_error_when_any_on_complete_block_in_batch_is_already_set
    m1 = m.initialize_batch_obj
    
    m1.unbatched_on_complete {}
    assert !m.on_complete_block
    
    assert_raise(RuntimeError) { m.on_complete {} }
    assert_raise(RuntimeError) { m.on_complete }
  end
  
  def test_on_complete_with_override_overrides_all_on_complete_blocks_in_batch
    m1 = m.initialize_batch_obj
    m.on_complete {}
    b = lambda {}
    
    assert_not_equal b, m.on_complete_block
    assert_not_equal b, m1.on_complete_block
    
    m.on_complete(true, &b)
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
  end
  
  def test_on_complete_with_override_and_no_block_sets_on_complete_block_to_nil_for_each_in_batch
    m1 = m.initialize_batch_obj
    m.on_complete {}
  
    assert_not_equal nil, m.on_complete_block
    assert_not_equal nil, m1.on_complete_block
    
    m.on_complete(true)
    
    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  end
  
  def test_on_complete_returns_self
    assert_equal m, m.on_complete
  end
  
  #
  # unbatched_on_complete test
  #
  
  def test_unbatched_on_complete_sets_on_complete_block_only_for_self
    m1 = m.initialize_batch_obj
    
    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  
    b = lambda {}
    m.unbatched_on_complete(&b)
    
    assert_equal b, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  end
  
  def test_unbatched_on_complete_raises_error_when_on_complete_block_is_already_set
    m.unbatched_on_complete {}
    assert_raise(RuntimeError) { m.unbatched_on_complete {} }
    assert_raise(RuntimeError) { m.unbatched_on_complete }
  end
  
  def test_unbatched_on_complete_with_override_overrides_complete_block_only_for_self
    m1 = m.initialize_batch_obj
  
    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block
    
    b = lambda {}
    m.unbatched_on_complete(true, &b)
    
    assert_equal b, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  end
  
  def test_unbatched_on_complete_with_override_and_no_block_sets_on_complete_block_to_nil_only_for_self
    m1 = m.initialize_batch_obj
    m.on_complete {}
  
    assert_not_equal nil, m.on_complete_block
    assert_not_equal nil, m1.on_complete_block
    
    m.unbatched_on_complete(true)
    
    assert_equal nil, m.on_complete_block
    assert_not_equal nil, m1.on_complete_block
  end
  
  def test_unbatched_on_complete_returns_self
    assert_equal m, m.unbatched_on_complete
  end
  
  class Tracer
    include Tap::Support::Executable
    
    class << self
      def intern(n, app, runlist)
        Array.new(n) { |index| new(index, app, runlist) }
      end
    end
    
    def initialize(index, app, runlist)
      @index = index
      @runlist = runlist
      
      @app = app
      @_method_name = :trace
      @on_complete_block =nil
      @dependencies = []
      @batch = [self]
    end
    
    def trace(trace)
      id = "#{@index}.#{batch_index}"
      
      @runlist << id
      trace = [trace] unless trace.kind_of?(Array)
      
      trace.collect do |str|
        str = str.inspect if str.kind_of?(Array)
        "#{str} #{id}".strip
      end
    end
  end
  
  #
  # sequence tests
  #
  
  def test_simple_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, app, runlist)
    
    t0_0.sequence(t1_0)
    t0_0.enq [""]
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]]
    ], app._results(t1_0))
  end
  
  def test_batch_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    
    t0_0.sequence(t1_0)
    t0_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0 1.0 
          1.1
      0.1 1.0 
          1.1
    }, runlist
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_0,['0.1 1.0']]]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_1,['0.0 1.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_1,['0.1 1.1']]], 
    ], app._results(t1_1))
  end
  
  def test_stack_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, app, runlist)
    
    t0_0.sequence(t1_0, :stack => true)
    t0_0.enq [""]
    app.run
  
    assert_equal %w{
      0.0 1.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]]
    ], app._results(t1_0))
  end
  
  def test_batched_stack_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    
    t0_0.sequence(t1_0, :stack => true)
    t0_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0      0.1
      1.0 1.1  1.0 1.1
    }, runlist
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_0,['0.1 1.0']]]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_1,['0.0 1.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_1,['0.1 1.1']]], 
    ], app._results(t1_1))
  end
  
  def test_iterate_sequence
    runlist = []
    t0_0, t1_0 = Tracer.intern(2, app, runlist)
  
    t0_0.sequence(t1_0, :iterate => true)
    t0_0.enq ['a', 'b']
    app.run
  
    assert_equal %w{
      0.0 1.0
          1.0
    }, runlist

    assert_audits_equal([
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(0), 'a 0.0'],[t1_0, ['a 0.0 1.0']]],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(1), 'b 0.0'],[t1_0, ['b 0.0 1.0']]]
    ], app._results(t1_0))
  end
  
  #
  # fork tests
  #
  
  def test_simple_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    
    t0_0.fork(t1_0, t2_0)
    t0_0.enq [""]
    app.run
  
    assert_equal %w{
      0.0 1.0
          2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_batch_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t0_0.fork(t1_0, t2_0)
    t0_0.enq ['']
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
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_0,['0.1 1.0']]]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_1,['0.0 1.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_1,['0.1 1.1']]], 
    ], app._results(t1_1))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_0,['0.1 2.0']]]
    ], app._results(t2_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_1,['0.0 2.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_1,['0.1 2.1']]], 
    ], app._results(t2_1))
  end
  
  def test_stack_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    
    t0_0.fork(t1_0, t2_0, :stack => true)
    t0_0.enq [""]
    app.run
  
    assert_equal %w{
      0.0 1.0
          2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_batched_stack_fork
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t0_0.fork(t1_0, t2_0, :stack => true)
    t0_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0             0.1
      1.0 1.1 2.0 2.1 1.0 1.1 2.0 2.1
    }, runlist
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_0,['0.0 1.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_0,['0.1 1.0']]]
    ], app._results(t1_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t1_1,['0.0 1.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t1_1,['0.1 1.1']]], 
    ], app._results(t1_1))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_0,['0.1 2.0']]]
    ], app._results(t2_0))
      
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_1,['0.0 2.1']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_1,['0.1 2.1']]], 
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
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(0), 'a 0.0'],[t1_0, ['a 0.0 1.0']]],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(1), 'b 0.0'],[t1_0, ['b 0.0 1.0']]]
    ], app._results(t1_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(0), 'a 0.0'],[t2_0, ['a 0.0 2.0']]],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(1), 'b 0.0'],[t2_0, ['b 0.0 2.0']]]
    ], app._results(t2_0))
  end
  
  #
  # merge tests
  #
  
  def test_simple_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.merge(t0_0, t1_0)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0 2.0
      1.0 2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]], 
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_0,['1.0 2.0']]],
    ], app._results(t2_0))
  end
  
  def test_batch_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.merge(t0_0, t1_0)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0 2.0
          2.1
      0.1 2.0
          2.1
      1.0 2.0
          2.1
      1.1 2.0
          2.1
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_0,['0.1 2.0']]], 
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_0,['1.0 2.0']]], 
      ExpAudit[[nil,['']],[t1_1,['1.1']],[t2_0,['1.1 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_1,['0.0 2.1']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_1,['0.1 2.1']]],
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_1,['1.0 2.1']]],
      ExpAudit[[nil,['']],[t1_1,['1.1']],[t2_1,['1.1 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_stack_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.merge(t0_0, t1_0, :stack => true)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0 1.0
      2.0 2.0
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]], 
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_0,['1.0 2.0']]],
    ], app._results(t2_0))
  end
  
  def test_stack_batch_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.merge(t0_0, t1_0, :stack => true)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0     0.1     1.0     1.1
      2.0 2.1 2.0 2.1 2.0 2.1 2.0 2.1
    }, runlist
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_0,['0.0 2.0']]], 
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_0,['0.1 2.0']]], 
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_0,['1.0 2.0']]], 
      ExpAudit[[nil,['']],[t1_1,['1.1']],[t2_0,['1.1 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[[nil,['']],[t0_0,['0.0']],[t2_1,['0.0 2.1']]],
      ExpAudit[[nil,['']],[t0_1,['0.1']],[t2_1,['0.1 2.1']]],
      ExpAudit[[nil,['']],[t1_0,['1.0']],[t2_1,['1.0 2.1']]],
      ExpAudit[[nil,['']],[t1_1,['1.1']],[t2_1,['1.1 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_iterate_merge
    runlist = []
    t0_0, t1_0, t2_0= Tracer.intern(3, app, runlist)
  
    t2_0.merge(t0_0, t1_0, :iterate => true)
    t0_0.enq ['a', 'b']
    t1_0.enq ['c', 'd']
    app.run
  
    assert_equal %w{
      0.0 2.0
          2.0
      1.0 2.0
          2.0
    }, runlist

    assert_audits_equal([
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(0), 'a 0.0'],[t2_0, ['a 0.0 2.0']]],
      ExpAudit[[nil,['a', 'b']],[t0_0,['a 0.0', 'b 0.0']],[AuditExpand.new(1), 'b 0.0'],[t2_0, ['b 0.0 2.0']]],
      ExpAudit[[nil,['c', 'd']],[t1_0,['c 1.0', 'd 1.0']],[AuditExpand.new(0), 'c 1.0'],[t2_0, ['c 1.0 2.0']]],
      ExpAudit[[nil,['c', 'd']],[t1_0,['c 1.0', 'd 1.0']],[AuditExpand.new(1), 'd 1.0'],[t2_0, ['d 1.0 2.0']]]
    ], app._results(t2_0))
  end
  
  #
  # sync_merge tests
  #
  
  def test_simple_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.sync_merge(t0_0, t1_0)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0
      1.0 2.0
    }, runlist
    
    m0_0 = ExpAudit[[nil,['']],[t0_0,['0.0']]]
    m1_0 = ExpAudit[[nil,['']],[t1_0,['1.0']]]

    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['["0.0"] 2.0', '["1.0"] 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_batch_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.sync_merge(t0_0, t1_0)
    t0_0.enq ['']
    t1_0.enq ['']
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
    
    m0_0 = ExpAudit[[nil,['']],[t0_0,['0.0']]]
    m0_1 = ExpAudit[[nil,['']],[t0_1,['0.1']]]
    m1_0 = ExpAudit[[nil,['']],[t1_0,['1.0']]]
    m1_1 = ExpAudit[[nil,['']],[t1_1,['1.1']]]
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['["0.0"] 2.0', '["1.0"] 2.0']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_0,['["0.0"] 2.0', '["1.1"] 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_0,['["0.1"] 2.0', '["1.0"] 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_0,['["0.1"] 2.0', '["1.1"] 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_1,['["0.0"] 2.1', '["1.0"] 2.1']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_1,['["0.0"] 2.1', '["1.1"] 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_1,['["0.1"] 2.1', '["1.0"] 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_1,['["0.1"] 2.1', '["1.1"] 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_stack_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)

    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ['']
    t1_0.enq ['']
    app.run
  
    assert_equal %w{
      0.0
      1.0 2.0
    }, runlist
    
    m0_0 = ExpAudit[[nil,['']],[t0_0,['0.0']]]
    m1_0 = ExpAudit[[nil,['']],[t1_0,['1.0']]]

    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['["0.0"] 2.0', '["1.0"] 2.0']]]
    ], app._results(t2_0))
  end
  
  def test_stack_batch_sync_merge
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
    t0_1 = t0_0.initialize_batch_obj
    t1_1 = t1_0.initialize_batch_obj
    t2_1 = t2_0.initialize_batch_obj
    
    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ['']
    t1_0.enq ['']
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
    
    m0_0 = ExpAudit[[nil,['']],[t0_0,['0.0']]]
    m0_1 = ExpAudit[[nil,['']],[t0_1,['0.1']]]
    m1_0 = ExpAudit[[nil,['']],[t1_0,['1.0']]]
    m1_1 = ExpAudit[[nil,['']],[t1_1,['1.1']]]
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_0,['["0.0"] 2.0', '["1.0"] 2.0']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_0,['["0.0"] 2.0', '["1.1"] 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_0,['["0.1"] 2.0', '["1.0"] 2.0']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_0,['["0.1"] 2.0', '["1.1"] 2.0']]]
    ], app._results(t2_0))
    
    assert_audits_equal([
      ExpAudit[ExpMerge[m0_0,m1_0], [t2_1,['["0.0"] 2.1', '["1.0"] 2.1']]],
      ExpAudit[ExpMerge[m0_0,m1_1], [t2_1,['["0.0"] 2.1', '["1.1"] 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_0], [t2_1,['["0.1"] 2.1', '["1.0"] 2.1']]],
      ExpAudit[ExpMerge[m0_1,m1_1], [t2_1,['["0.1"] 2.1', '["1.1"] 2.1']]]
    ], app._results(t2_1))
  end
  
  def test_sync_merge_raises_error_if_target_cannot_be_enqued_before_a_source_executes_twice
    runlist = []
    t0_0, t1_0, t2_0 = Tracer.intern(3, app, runlist)
  
    t2_0.sync_merge(t0_0, t1_0, :stack => true)
    t0_0.enq ['']
    t0_0.enq ['']
    t1_0.enq ['']
    
    assert_raise(RuntimeError) { app.run }
    assert_equal %w{
      0.0
      0.0
    }, runlist
  end
  
  #
  # depends_on test
  #
  
  class Dependency
    attr_reader :resolve_arguments
    
    def initialize(trace=[])
      @resolve_arguments = []
      @trace = trace
      Tap::Support::Executable.initialize(self, :resolve)
    end
    
    def resolve(*args)
      @trace << self
      @resolve_arguments << args
      args.join(",")
    end
  end
  
  def test_depends_on_registers_dependency_with_Executable_and_adds_index_to_dependencies
    app.dependencies.registry << [:a, []]
  
    d1 = Dependency.new
    d2 = Dependency.new
    
    m.depends_on(d1)
    m.depends_on(d2, 1,2,3)
    
    assert_equal [[:a, []], [d1, []], [d2, [1,2,3]]], app.dependencies.registry
    assert_equal [1,2], m.dependencies
  end
  
  def test_depends_on_returns_index_of_dependency
    d1 = Dependency.new
    d2 = Dependency.new
    
    assert_equal 0, m.depends_on(d1)
    assert_equal 1, m.depends_on(d2, 1,2,3)
    
    assert_equal [[d1, []], [d2, [1,2,3]]], app.dependencies.registry
  end
  
  def test_depends_on_raises_error_for_non_Executable_dependencies
    assert_raise(ArgumentError) { m.depends_on nil }
    assert_raise(ArgumentError) { m.depends_on Object.new }
  end
  
  def test_depends_on_raises_error_for_self_as_dependency
    assert_raise(ArgumentError) { m.depends_on m }
  end
  
  def test_depends_on_removes_duplicate_dependencies
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.depends_on d
    m.depends_on d, 1,2,3
    
    assert_equal 2, m.dependencies.length
  end
  
  #
  # resolve_dependencies test
  #
  
  def test_resolve_dependencies_calls_execute_with_args_for_each_dependency
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.resolve_dependencies
    assert_equal [[], [1,2,3]], d.resolve_arguments
  end
  
  def test_resolve_dependencies_recollects_dependencies_as_audited_dependency_results
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.resolve_dependencies
    
    assert_equal 2, m.dependencies.length
    assert_equal ["", "1,2,3"], m.dependencies.collect {|index| app.dependencies.results[index]._current }
  end
  
  def test_resolve_dependencies_does_not_re_execute_resolved_dependencies
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.resolve_dependencies
    assert_equal [[], [1,2,3]], d.resolve_arguments
    
    m.resolve_dependencies
    assert_equal [[], [1,2,3]], d.resolve_arguments
  end
  
  def test_resolve_dependencies_returns_self
    assert_equal m, m.resolve_dependencies
  end
  
  def test_resolve_resolves_nested_dependencies
    resolve_trace = []
    
    a = Dependency.new resolve_trace
    b = Dependency.new resolve_trace
    c = Dependency.new resolve_trace
    
    m.depends_on(a)
    a.depends_on(b)
    a.depends_on(c)
    
    m.resolve_dependencies
    assert_equal [b, c, a], resolve_trace
  end
  
  def test_resolve_raises_error_for_circular_dependencies
    a = Dependency.new
    b = Dependency.new
  
    m.depends_on(a)
    a.depends_on(b)
    b.depends_on(m)
    
    assert_raise(Dependencies::CircularDependencyError) { m.resolve_dependencies }
    assert_raise(Dependencies::CircularDependencyError) { a.resolve_dependencies }
    assert_raise(Dependencies::CircularDependencyError) { b.resolve_dependencies }
  end
  
  #
  # reset_dependencies
  #
  
  def test_reset_dependencies_allows_dependencies_to_be_re_invoked
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.resolve_dependencies
    assert_equal [[], [1,2,3]], d.resolve_arguments
    
    m.resolve_dependencies
    assert_equal [[], [1,2,3]], d.resolve_arguments
    
    m.reset_dependencies
    m.resolve_dependencies
    assert_equal [[], [1,2,3], [], [1,2,3]], d.resolve_arguments
  end
  
  def test_reset_dependencies_returns_self
    assert_equal m, m.reset_dependencies
  end
  
  #
  # Object#_method test
  #
  
  def test__method_doc
    array = []
    push_to_array = array._method(:push)
  
    task = Tap::Task.new  
    task.sequence(push_to_array)
  
    task.enq(1).enq(2,3)
    task.app.run
  
    assert_equal [[1],[2,3]], array
  end

end