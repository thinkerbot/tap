require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class DeclarationTaskTest < Test::Unit::TestCase
  include Rap
  
  def setup
    Rap::Declarations.env = Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
  end
  
  def teardown
    0.upto(3) do |n|    
      const_name = "Task#{n}".to_sym
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
  end
  
  #
  # interface tests
  #
  
  def test_declaration_API_is_hidden_on_declaration_tasks
    assert !DeclarationTask.respond_to?(:namespace)
    assert !DeclarationTask.respond_to?(:desc)
    assert !DeclarationTask.respond_to?(:register)
  end
  
  #
  # declare test
  #
  
  class DeclarationSubclass < DeclarationTask
  end
  
  def test_declare_returns_a_subclass_of_self
    assert_equal DeclarationTask, DeclarationTask.declare(:task0).class.superclass
    assert_equal DeclarationSubclass, DeclarationSubclass.declare(:task1).class.superclass
  end
  
  #
  # subclass test
  #
  
  class Subclass < DeclarationTask
  end
  
  def test_subclass_defines_and_returns_a_subclass_of_self
    assert !Object.const_defined?(:Task0)
    assert !Object.const_defined?(:Task1)
    
    t0 = DeclarationTask.subclass('Task0')
    assert_equal Task0, t0
    assert_equal DeclarationTask, t0.superclass
    
    t1 = Subclass.subclass('Task1')
    assert_equal Task1, t1
    assert_equal Subclass, t1.superclass
  end
  
  def test_subclass_assigns_subclass_to_const_name
    assert !Object.const_defined?(:Task0)
    assert_equal DeclarationTask.subclass('Task0'), Task0
  end
  
  def test_subclass_nests_nested_const_names_in_DeclarationTasks
    assert !Object.const_defined?(:Task0)
    assert_equal DeclarationTask.subclass('Task0::Task1'), Task0::Task1
    assert_equal DeclarationTask, Task0.superclass
  end
  
  def test_subclass_nests_nested_const_names_in_DeclarationTasks_even_for_subclass_callers
    assert !Object.const_defined?(:Task0)
    assert_equal Subclass.subclass('Task0::Task1'), Task0::Task1
    assert_equal Subclass, Task0::Task1.superclass
    assert_equal DeclarationTask, Task0.superclass
  end
  
  def test_subclass_adds_configurations_to_subclass
    DeclarationTask.subclass('Task0')
    assert_equal({}, Task0.configurations)
    
    DeclarationTask.subclass('Task0', :key => 'value')
    assert_equal({:key => Configurable::Delegate.new(:key, :key=, 'value')}, Task0.configurations)
  end
  
  def test_subclass_adds_dependencies_to_subclass
    DeclarationTask.subclass('Task0')
    DeclarationTask.subclass('Task1')
    DeclarationTask.subclass('Task2')
    
    assert_equal([], Task0.dependencies)
    
    DeclarationTask.subclass('Task0', {}, [Task1, Task2])
    assert_equal([Task1, Task2], Task0.dependencies)
  end
  
  def test_subclass_raises_error_if_it_constant_which_is_not_a_subclass_of_self
    e = assert_raises(RuntimeError) { DeclarationTask.subclass('Object') }
    assert_equal "not a Rap::DeclarationTask: Object", e.message
    
     DeclarationTask.subclass('Task0')
    e = assert_raises(RuntimeError) { Subclass.subclass('Task0') }
    assert_equal "not a DeclarationTaskTest::Subclass: Task0", e.message
  end
end