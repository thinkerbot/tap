require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/declarations'

Tap.extend Tap::Support::Declarations

class DeclarationsTest < Test::Unit::TestCase
  include Tap::Support::Declarations
  
  #
  # tasc declaration
  #
  
  def test_tasc_generates_subclass_of_Task_by_name
    assert !DeclarationsTest.const_defined?(:Declaration1)
    klass = tasc(:declaration1)
    assert_equal DeclarationsTest::Declaration1, klass
    assert_equal Tap::Task, klass.superclass
  end
  
  def test_subclass_is_assigned_configurations
    klass = tasc(:declaration2, {:key => 'value'})
    assert_equal({:key => 'value'}, klass.configurations.to_hash)
  end
  
  def test_subclass_sets_block_as_process
    was_in_block = false
    klass = tasc(:declaration3) do
      was_in_block = true
    end
    
    assert !was_in_block
    klass.new.process
    assert was_in_block
  end
  
  def test_subclass_sets_dependencies_using_initial_hash_if_given
    klass = tasc(:declaration4 => Tap::Task)
    assert_equal [
      [Tap::Task, []]
    ], klass.dependencies
    
    
    klass = tasc(:declaration5 => [Tap::Task, Tap::FileTask])
    assert_equal [
      [Tap::Task, []], 
      [Tap::FileTask, []]
    ], klass.dependencies

    klass = tasc(:declaration6 => [[:task, Tap::Task], [:file_task, Tap::FileTask, 1,2,3]])
    assert_equal [
      [Tap::Task, []], 
      [Tap::FileTask, [1,2,3]]
    ], klass.dependencies
  end
  
  #
  # tasc nesting
  #
  
  module Nest
    extend Tap::Support::Declarations
    tasc(:sample) {}
  end
 
  def test_declarations_nest_constant
    const = tasc(:sample)
    assert_equal "DeclarationsTest::Sample", const.to_s
    
    assert Nest.const_defined?("Sample")
  end
  
  def test_declarations_are_not_nested_for_tap
    const = Tap.tasc(:sample_declaration)
    assert_equal "SampleDeclaration", const.to_s
  end

  #
  # task declaration
  #
  
  def test_task_generates_subclass_of_Rake_by_name
    assert !DeclarationsTest.const_defined?(:Rake1)
    task(:rake1)
    assert DeclarationsTest.const_defined?(:Rake1)
    assert_equal Tap::Tasks::Rake, Rake1.superclass
  end
  
  def test_task_returns_instance_of_Rake_subclass
    result = task(:rake2)
    assert_equal Rake2.instance, result 
  end
  
  def test_task_adds_block_to_subclass_actions
    block_one = lambda {}
    block_two = lambda {}
    
    task(:rake3, &block_one)
    assert_equal [block_one], Rake3.actions 
    
    task(:rake3, &block_two)
    assert_equal [block_one, block_two], Rake3.actions 
  end
  
end