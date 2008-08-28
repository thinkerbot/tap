require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/declarations'

Tap.extend Tap::Support::Declarations

class DeclarationsTest < Test::Unit::TestCase
  include Tap::Support::Declarations
  
  #
  # tasc declaration
  #
  
  def test_tasc_generates_subclass_of_Task_by_name
    assert !DeclarationsTest.const_defined?(:Subclass1)
    klass = tasc(:subclass1)
    assert_equal DeclarationsTest::Subclass1, klass
  end
  
  def test_subclass_is_assigned_configurations
    klass = tasc(:subclass2, {:key => 'value'})
    assert_equal({:key => 'value'}, klass.configurations.to_hash)
  end
  
  def test_subclass_sets_block_as_process
    was_in_block = false
    klass = tasc(:subclass3) do
      was_in_block = true
    end
    
    assert !was_in_block
    klass.new.process
    assert was_in_block
  end
  
  def test_subclass_sets_dependencies_using_initial_hash_if_given
    klass = tasc(:subclass4 => [Tap::Task, [:file_task, Tap::FileTask, 1,2,3]])
    assert_equal [
      [Tap::Task, []], 
      [Tap::FileTask, [1,2,3]]
    ], klass.dependencies
    
    klass = tasc(:subclass5 => Tap::Task)
    assert_equal [
      [Tap::Task, []]
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

end