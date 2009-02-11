require File.join(File.dirname(__FILE__), '../../tap_test_helper')
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
    assert_equal :object_id, m.method_name
    assert_equal Tap::App.instance, m.app
    assert_equal [], m.dependencies
    assert_nil m.on_complete_block
  end
  
  def test_initialize
    app = Tap::App.new
    m = Object.new
    b = lambda {}
    
    assert_equal m, Executable.initialize(m, :object_id, app, [1,2,3], &b)
    assert m.kind_of?(Executable)
    assert_equal :object_id, m.method_name
    assert_equal app, m.app
    assert_equal [1,2,3], m.dependencies
    assert_equal b, m.on_complete_block
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
  
  def test_enq_returns_self
    assert_equal m, m.enq
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_sets_on_complete_block_for_self
    assert_equal nil, m.on_complete_block

    b = lambda {}
    m.on_complete(&b)
    
    assert_equal b, m.on_complete_block
  end
  
  def test_on_complete_raises_error_when_an_on_complete_block_is_already_set
    m.on_complete {}
    assert m.on_complete_block
    
    assert_raises(RuntimeError) { m.on_complete {} }
    assert_raises(RuntimeError) { m.on_complete }
  end
  
  def test_on_complete_with_override_overrides_on_complete_block
    m.on_complete {}
    b = lambda {}
    
    assert b.object_id != m.on_complete_block.object_id
    m.on_complete(true, &b)
    assert_equal b.object_id, m.on_complete_block.object_id
  end
  
  def test_on_complete_with_override_and_no_block_sets_on_complete_block_to_nil
    m.on_complete {}
  
    assert nil != m.on_complete_block
    m.on_complete(true)
    
    assert_equal nil, m.on_complete_block
  end
  
  def test_on_complete_returns_self
    assert_equal m, m.on_complete
  end
  
  #
  # depends_on test
  #
  
  class DependencyTrace
    def initialize(trace=[])
      @trace = trace
      Tap::Support::Executable.initialize(self, :trace)
    end
    
    def trace(*args)
      @trace << self
      args.join(",")
    end
  end
  
  def test_depends_on_pushes_dependency_onto_dependencies
    m.dependencies << nil
    
    d1 = DependencyTrace.new
    m.depends_on(d1)
    assert_equal [nil, d1], m.dependencies
  end
  
  def test_depends_on_does_not_add_duplicates
    d1 = DependencyTrace.new
    m.dependencies << d1
    
    m.depends_on(d1)
    assert_equal [d1], m.dependencies
  end
  
  def test_depends_on_extends_dependency_with_Dependency
    d1 = DependencyTrace.new
    assert !d1.kind_of?(Dependency)
    
    m.depends_on(d1)
    assert d1.kind_of?(Dependency)
  end
  
  def test_depends_on_raises_error_for_self_as_dependency
    assert_raises(ArgumentError) { m.depends_on m }
  end
  
  #
  # resolve_dependencies test
  #
  
  def test_resolve_dependencies_resolves_each_dependency
    trace = []
    d1 = DependencyTrace.new trace
    d2 = DependencyTrace.new trace
    
    m.depends_on d1
    m.depends_on d2
    
    assert !d1.resolved?
    assert !d2.resolved?
    
    m.resolve_dependencies
    
    assert d1.resolved?
    assert d2.resolved?
    assert_equal [d1, d2], trace
  end
  
  def test_resolve_dependencies_does_not_resolve_dependencies_once_they_are_resolved
    trace = []
    d1 = DependencyTrace.new trace
    d2 = DependencyTrace.new trace
    
    m.depends_on d1
    m.depends_on d2
    
    m.resolve_dependencies
    assert_equal [d1, d2], trace
    
    m.resolve_dependencies
    assert_equal [d1, d2], trace
  end
  
  def test_resolve_dependencies_returns_self
    assert_equal m, m.resolve_dependencies
  end
  
  def test_resolve_resolves_nested_dependencies
    resolve_trace = []
    
    a = DependencyTrace.new resolve_trace
    b = DependencyTrace.new resolve_trace
    c = DependencyTrace.new resolve_trace
    
    m.depends_on(a)
    a.depends_on(b)
    a.depends_on(c)
    
    m.resolve_dependencies
    assert_equal [b, c, a], resolve_trace
  end
  
  def test_resolve_raises_error_for_circular_dependencies
    a = DependencyTrace.new
    b = DependencyTrace.new
  
    m.depends_on(a)
    a.depends_on(b)
    b.depends_on(m)
    
    assert_raises(Dependencies::CircularDependencyError) { m.resolve_dependencies }
    assert_raises(Dependencies::CircularDependencyError) { a.resolve_dependencies }
    assert_raises(Dependencies::CircularDependencyError) { b.resolve_dependencies }
  end
  
  #
  # reset_dependencies
  #
  
  def test_reset_dependencies_allows_dependencies_to_be_re_resolved
    trace = []
    d1 = DependencyTrace.new trace
    d2 = DependencyTrace.new trace
    
    m.depends_on d1
    m.depends_on d2
    
    m.resolve_dependencies
    assert_equal [d1, d2], trace
    
    m.resolve_dependencies
    assert_equal [d1, d2], trace
    
    m.reset_dependencies
    m.resolve_dependencies
    assert_equal [d1, d2, d1, d2], trace
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