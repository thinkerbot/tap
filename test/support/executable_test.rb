require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable'

class ExecutableTest < Test::Unit::TestCase
  include Tap::Support

  attr_accessor :m
  
  def setup
    @m = Executable.initialize(Object.new, :object_id)
    Executable.clear_dependencies
  end
  
  #
  # initialization tests
  #
  
  def test_initialization
    assert_nil m.on_complete_block
    assert_equal [], m.dependencies
  end
  
  #
  # on_complete block test
  #
  
  def test_on_complete_sets_on_complete_block
    block = lambda {}
    m.on_complete(&block)
    assert_equal block, m.on_complete_block
  end
  
  def test_on_complete_can_only_be_set_once
    m.on_complete {}
    assert_raise(RuntimeError) { m.on_complete {} }
    assert_raise(RuntimeError) { m.on_complete }
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
    Executable.registry << [:a, []]

    d1 = Dependency.new
    d2 = Dependency.new
    
    m.depends_on(d1)
    m.depends_on(d2, 1,2,3)
    
    assert_equal [[:a, []], [d1, []], [d2, [1,2,3]]], Executable.registry
    assert_equal [1,2], m.dependencies
  end
  
  def test_depends_on_returns_index_of_dependency
    d1 = Dependency.new
    d2 = Dependency.new
    
    assert_equal 0, m.depends_on(d1)
    assert_equal 1, m.depends_on(d2, 1,2,3)
    
    assert_equal [[d1, []], [d2, [1,2,3]]], Executable.registry
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
    assert_equal ["", "1,2,3"], m.dependencies.collect {|index| Executable.results[index]._current }
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
    
    assert_raise(Dependable::CircularDependencyError) { m.resolve_dependencies }
    assert_raise(Dependable::CircularDependencyError) { a.resolve_dependencies }
    assert_raise(Dependable::CircularDependencyError) { b.resolve_dependencies }
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
  # batch test
  #
  
  def test_batch_with
    m1 = Executable.initialize(Object.new, :object_id)
    m2 = Executable.initialize(Object.new, :object_id)
    m3 = Executable.initialize(Object.new, :object_id)

    m1.batch_with(m2, m3)
    
    assert_equal [m1, m2, m3], m1.batch
    assert_equal [m1, m2, m3], m2.batch
    assert_equal [m1, m2, m3], m3.batch
  end
  
  #
  # batched? test
  #
  
  def test_batched_returns_true_if_batch_size_is_greater_than_one
    assert !m.batched?
    assert_equal 1, m.batch.size
    
    m1 = Executable.initialize(Object.new, :object_id)
    m.batch_with(m1)
    
    assert m.batched?
    assert m1.batched?
  end
  
  #
  # batch_index test
  #
  
  def test_batch_index_returns_the_index_of_the_task_in_batch
    m1 = Executable.initialize(Object.new, :object_id)
    m.batch_with(m1)
    
    assert_equal [m, m1], m.batch
    assert_equal 0, m.batch_index
    assert_equal 1, m1.batch_index
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