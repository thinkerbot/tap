require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/node'

class NodeTest < Test::Unit::TestCase
  Node = Tap::App::Node
  Audit = Tap::App::Audit
  Dependency = Tap::App::Dependency
  
  attr_accessor :m
  
  def setup
    @m = lambda {}.extend Node
  end
  
  #
  # intern tests
  #
  
  def test_intern_makes_node_from_block
    m = Node.intern { "result" }
    assert m.kind_of?(Node)
    assert_equal nil, m.app
    assert_equal nil, m.join
    assert_equal [], m.dependencies
    assert_equal "result", m.call
  end
  
  #
  # extend tests
  #
  
  def test_extend_initializes_defaults
    m = lambda {}.extend Node
    assert m.kind_of?(Node)
    assert_equal nil, m.app
    assert_equal nil, m.join
    assert_equal [], m.dependencies
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_sets_join_for_self
    assert_equal nil, m.join

    b = lambda {}
    m.on_complete(&b)
    
    assert_equal b, m.join
  end
  
  def test_on_complete_returns_self
    assert_equal m, m.on_complete
  end
  
  #
  # depends_on test
  #
  
  class DependencyTrace
    include Tap::App::Node
    
    def initialize(trace=[])
      @trace = trace
      @join = nil
      @dependencies = []
    end
    
    def call
      @trace << self
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
    err = assert_raises(ArgumentError) { m.depends_on m }
    assert_equal "cannot depend on self", err.message
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
    trace = []

    a = DependencyTrace.new trace
    b = DependencyTrace.new trace
    c = DependencyTrace.new trace

    m.depends_on(a)
    a.depends_on(b)
    a.depends_on(c)

    m.resolve_dependencies
    assert_equal [b, c, a], trace
  end

  def test_resolve_raises_error_for_circular_dependencies
    a = DependencyTrace.new
    b = DependencyTrace.new
  
    m.depends_on(a)
    a.depends_on(b)
    b.depends_on(m)
  
    assert_raises(Node::CircularDependencyError) { m.resolve_dependencies }
    assert_raises(Node::CircularDependencyError) { a.resolve_dependencies }
    assert_raises(Node::CircularDependencyError) { b.resolve_dependencies }
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
end