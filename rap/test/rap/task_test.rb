require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/task'

class RapTaskTest < Test::Unit::TestCase
  include Rap
  
  def teardown
    0.upto(3) do |n|    
      const_name = "Task#{n}".to_sym
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
  end
  
  #
  # dependencies test
  #
  
  def test_dependencies_are_empty_by_default
    assert_equal [], Rap::Task.dependencies
  end
   
  #
  # Task.depends_on test
  #
  
  class A < Rap::Task
  end
  
  class B < Rap::Task
    depends_on :a, A
  end
  
  def test_depends_on_documentation
    app = Tap::App.new
    b = B.new({}, app)
    assert_equal [A.instance(app)], b.dependencies
    assert_equal A.instance(app), b.a 
  end
  
  class DependencyClassOne < Rap::Task
  end
  
  class DependencyClassTwo < Rap::Task
  end
  
  class DependentClass < Rap::Task
    depends_on :one, DependencyClassOne
    depends_on nil, DependencyClassTwo
  end
  
  def test_depends_on_adds_dependency_class_to_dependencies
    assert_equal [DependencyClassOne, DependencyClassTwo], DependentClass.dependencies
  end
  
  def test_depends_on_makes_a_reader_for_the_dependency_instance
    d = DependentClass.new
    assert d.respond_to?(:one)
    assert_equal DependencyClassOne.instance, d.one
  end
  
  def test_depends_on_returns_self
    assert_equal DependentClass, DependentClass.send(:depends_on, :one, DependencyClassOne)
  end
  
  class DependentDupClass < Rap::Task
    depends_on :one, DependencyClassOne
    depends_on :one, DependencyClassOne
  end
  
  def test_depends_on_does_not_add_duplicates
    assert_equal [DependencyClassOne], DependentDupClass.dependencies
  end
  
  class DependentParentClass < Rap::Task
    depends_on :one, DependencyClassOne
  end
  
  class DependentSubClass < DependentParentClass
    depends_on :two, DependencyClassTwo
  end
  
  def test_dependencies_are_inherited_down_but_not_up
    assert_equal [DependencyClassOne], DependentParentClass.dependencies
    assert_equal [DependencyClassOne, DependencyClassTwo], DependentSubClass.dependencies
  end
  
  #
  # subclass test
  #
  
  class Subclass < Task
  end
  
  def test_subclass_defines_and_returns_a_subclass_of_self
    assert !Object.const_defined?(:Task0)
    assert !Object.const_defined?(:Task1)
    
    t0 = Task.subclass('Task0')
    assert_equal Task0, t0
    assert_equal Task, t0.superclass
    
    t1 = Subclass.subclass('Task1')
    assert_equal Task1, t1
    assert_equal Subclass, t1.superclass
  end
  
  def test_subclass_assigns_subclass_to_const_name
    assert !Object.const_defined?(:Task0)
    assert_equal Task.subclass('Task0'), Task0
  end
  
  def test_subclass_nests_nested_const_names_in_Tasks
    assert !Object.const_defined?(:Task0)
    assert_equal Task.subclass('Task0::Task1'), Task0::Task1
    assert_equal Task, Task0.superclass
  end
  
  def test_subclass_nests_nested_const_names_in_Tasks_even_for_subclass_callers
    assert !Object.const_defined?(:Task0)
    assert_equal Subclass.subclass('Task0::Task1'), Task0::Task1
    assert_equal Subclass, Task0::Task1.superclass
    assert_equal Task, Task0.superclass
  end
  
  def test_subclass_adds_configurations_to_subclass
    Task.subclass('Task0')
    assert_equal({}, Task0.configurations)
    
    Task.subclass('Task0', :key => 'value')
    config = Task0.configurations[:key]
    assert_equal([:key, :key=, 'value'], [config.reader, config.writer, config.default])
  end
  
  def test_subclass_adds_dependencies_to_subclass
    Task.subclass('Task0')
    Task.subclass('Task1')
    Task.subclass('Task2')
    
    assert_equal([], Task0.dependencies)
    
    Task.subclass('Task0', {}, [Task1, Task2])
    assert_equal([Task1, Task2], Task0.dependencies)
  end
  
  def test_subclass_raises_error_if_it_constant_which_is_not_a_subclass_of_self
    e = assert_raises(RuntimeError) { Task.subclass('Object') }
    assert_equal "not a Rap::Task: Object", e.message
    
     Task.subclass('Task0')
    e = assert_raises(RuntimeError) { Subclass.subclass('Task0') }
    assert_equal "not a RapTaskTest::Subclass: Task0", e.message
  end
  
  #
  # call test
  #

  def test_call_resolves_dependencies_of_task
    t0 = Task.subclass('Task0').instance
    t1 = Task.subclass('Task1').instance
    t2 = Task.subclass('Task2').instance
    
    t0.depends_on(t1)
    t1.depends_on(t2)

    t0.call
    assert t1.resolved?
    assert t2.resolved?
  end

  def test_call_raises_error_for_circular_dependencies
    t0 = Task.subclass('Task0').instance
    t1 = Task.subclass('Task1').instance
    t2 = Task.subclass('Task2').instance
    
    t0.depends_on(t1)
    t1.depends_on(t2)
    t2.depends_on(t0)

    err = assert_raises(DependencyError) { t0.call }
    assert_equal "circular dependency: [Task0, Task1, Task2, Task0]", err.message
  end
  
  #
  # depends_on test
  #

  def test_depends_on_pushes_dependency_onto_dependencies
    t0 = Task.subclass('Task0').instance
    t1 = Task.subclass('Task1').instance
    
    t0.dependencies << nil
    
    t0.depends_on(t1)
    assert_equal [nil, t1], t0.dependencies
  end

  def test_depends_on_does_not_add_duplicates
    t0 = Task.subclass('Task0').instance
    t1 = Task.subclass('Task1').instance
    
    t0.depends_on(t1)
    t0.depends_on(t1)
    
    assert_equal [t1], t0.dependencies
  end

  def test_depends_on_raises_error_for_self_as_dependency
    t0 = Task.subclass('Task0').instance
    err = assert_raises(RuntimeError) { t0.depends_on t0 }
    assert_equal "cannot depend on self", err.message
  end
  
end
