require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable'

class ExecutableTest < Test::Unit::TestCase
  include Tap

  attr_accessor :m
  
  def setup
    @m = Tap::Support::Executable.initialize(Object.new, :object_id)
  end
  
  #
  # initialization tests
  #
  
  def test_initialization
    assert !m.multithread
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
    
    def initialize
      @resolve_arguments = []
      Tap::Support::Executable.initialize(self, :resolve)
    end
    
    def resolve(*args)
      @resolve_arguments << args
      args.join(",")
    end
  end
  
  def test_depends_on_adds_dependency_and_args_to_dependencies
    d1 = Dependency.new
    d2 = Dependency.new
    
    m.depends_on d1
    m.depends_on d2, 1,2,3
    
    assert_equal [[d1, []], [d2, [1,2,3]]], m.dependencies
  end
  
  def test_depends_on_raises_error_for_non_Executable_dependencies
    assert_raise(ArgumentError) { m.depends_on nil }
    assert_raise(ArgumentError) { m.depends_on Object.new }
  end
  
  def test_depends_on_raises_error_for_self_as_dependency
    assert_raise(ArgumentError) { m.depends_on m }
  end
  
  def test_depends_on_returns_self
    assert_equal m, m.depends_on(Dependency.new)
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
    results = m.dependencies.collect do |result|
      assert_equal Support::Audit, result.class
      result._current
    end
    
    assert_equal ["", "1,2,3"], results
  end
  
  def test_resolve_dependencies_removes_duplicate_dependencies
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.depends_on d
    m.depends_on d, 1,2,3
    
    assert_equal 4, m.dependencies.length
    m.resolve_dependencies
    assert_equal 2, m.dependencies.length
    
    results = m.dependencies.collect do |result|
      assert_equal Support::Audit, result.class
      result._current
    end
    
    assert_equal ["", "1,2,3"], results
  end
  
  def test_resolve_dependencies_freezes_dependencies
    assert !m.dependencies.frozen?
    m.resolve_dependencies
    assert m.dependencies.frozen?
  end
  
  def test_resolve_dependencies_does_nothing_if_dependencies_is_frozen
    d = Dependency.new
  
    m.depends_on d
    m.depends_on d, 1,2,3
    
    m.dependencies.freeze
    assert m.dependencies.frozen?
    
    m.resolve_dependencies
    
    assert_equal [], d.resolve_arguments
    assert_equal [[d, []], [d,[1,2,3]]], m.dependencies
  end
  
  #
  # Object#_method test
  #
  
  def test__method_doc
    array = []
    push_to_array = array._method(:push)
  
    task = Tap::Task.new  
    task.app.sequence(task, push_to_array)
  
    task.enq(1).enq(2,3)
    task.app.run
  
    assert_equal [[1],[2,3]], array
  end

end