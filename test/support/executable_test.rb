require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable'

class ExecutableTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :m, :app
  
  def setup
    @app = Tap::App.new
    @m = new_executable
  end
  
  def new_executable(batch=[], app=app)
    Executable.initialize(Object.new, :object_id, app, batch)
  end
  
  #
  # initialization tests
  #
  
  def test_initialization
    app = Tap::App.new
    m = Object.new
    
    assert_equal m, Executable.initialize(m, :object_id, app, [1,2,3])
    assert m.kind_of?(Executable)
    assert_equal :object_id, m._method_name
    assert_equal app, m.app
    assert_equal [1,2,3,m], m.batch
    assert_nil m.on_complete_block
    assert_equal [], m.dependencies
  end
  
  def test_initialization_defaults
    m = Executable.initialize(Object.new, :object_id)
    assert m.kind_of?(Executable)
    assert_equal :object_id, m._method_name
    assert_equal Tap::App.instance, m.app
    assert_equal [m], m.batch
    assert_nil m.on_complete_block
    assert_equal [], m.dependencies
  end
  
  #
  # batched? test
  #
  
  def test_batched_returns_true_if_batch_size_is_greater_than_one
    assert !m.batched?
    assert_equal 1, m.batch.size
    
    m.batch << nil
    
    assert_equal 2, m.batch.size
    assert m.batched?
  end
  
  #
  # batch_index test
  #
  
  def test_batch_index_returns_the_index_of_the_task_in_batch
    assert_equal [m], m.batch
    assert_equal 0, m.batch_index
    
    m.batch.clear
    m.batch.concat [0,1,m]
    assert_equal 2, m.batch_index
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
    m1 = new_executable(m.batch)
    
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
    m1 = new_executable(m.batch)
    
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
    m1 = new_executable(m.batch)
    
    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block

    b = lambda {}
    m.on_complete(&b)
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
  end
  
  def test_on_complete_raises_error_when_any_on_complete_block_in_batch_is_already_set
    m1 = new_executable(m.batch)
    
    m1.unbatched_on_complete {}
    assert !m.on_complete_block
    
    assert_raise(RuntimeError) { m.on_complete {} }
    assert_raise(RuntimeError) { m.on_complete }
  end
  
  def test_on_complete_with_override_overrides_all_on_complete_blocks_in_batch
    m1 = new_executable(m.batch)
    m.on_complete {}
    b = lambda {}
    
    assert_not_equal b, m.on_complete_block
    assert_not_equal b, m1.on_complete_block
    
    m.on_complete(true, &b)
    
    assert_equal b, m.on_complete_block
    assert_equal b, m1.on_complete_block
  end
  
  def test_on_complete_with_override_and_no_block_sets_on_complete_block_to_nil_for_each_in_batch
    m1 = new_executable(m.batch)
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
    m1 = new_executable(m.batch)
    
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
    m1 = new_executable(m.batch)

    assert_equal nil, m.on_complete_block
    assert_equal nil, m1.on_complete_block
    
    b = lambda {}
    m.unbatched_on_complete(true, &b)
    
    assert_equal b, m.on_complete_block
    assert_equal nil, m1.on_complete_block
  end
  
  def test_unbatched_on_complete_with_override_and_no_block_sets_on_complete_block_to_nil_only_for_self
    m1 = new_executable(m.batch)
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
  # initialize_batch_obj test
  #
  
  # def test_created_batch_tasks_are_added_to_and_share_the_same_execute_batch
  #   assert_equal [m], m.batch
  #   
  #   m1 = m.initialize_batch_obj
  #   m2 = m1.initialize_batch_obj
  #   
  #   assert_equal [m, m1, m2], m.batch
  #   assert_equal m.batch.object_id, m1.batch.object_id
  #   assert_equal m.batch.object_id, m2.batch.object_id
  # end
  
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