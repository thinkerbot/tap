require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/declarations'

class TaskSubclassTest < Test::Unit::TestCase

  attr_accessor :subclass
  
  def setup
    @subclass = Class.new(Tap::Task)
    @subclass.extend Tap::Declarations::TaskSubclass
  end
  

  ### constants  ###

  # def test_subclass_generates_subclass_of_Task_by_name
  #   assert !Subclass.const_defined?(:One)
  #   subclass = Task.subclass('task_test/subclass/one')
  #   assert_equal Subclass::One, subclass
  #   assert_equal Task, subclass.superclass
  # end
  # 
  # def test_subclasses_can_generate_subclasses
  #   assert !Subclass.const_defined?(:TwoA)
  #   subclass_a = Task.subclass('task_test/subclass/two_a')
  #   subclass_b = subclass_a.subclass('task_test/subclass/two_b')
  # 
  #   assert_equal Subclass::TwoA, subclass_a
  #   assert_equal Subclass::TwoB, subclass_b
  #   assert_equal subclass_a, subclass_b.superclass
  # end
  # 
  # def test_subclass_generates_modules_as_needed
  #   assert !Subclass.const_defined?(:Nested)
  #   subclass = Task.subclass('task_test/subclass/nested/one')
  #   assert_equal Subclass::Nested::One, subclass
  # end
  # 
  # def test_subclass_generates_subclass_in_Object
  #   assert !Subclass.const_defined?(:Three)
  #   subclass = Task.subclass('object/task_test/subclass/three')
  #   assert_equal Subclass::Three, subclass
  # end

  # class ExistingSubclass < Tap::Task
  # end
  # 
  # def test_subclass_returns_existing_subclass
  #   assert_equal ExistingSubclass, Task.subclass('task_test/existing_subclass')
  # end
  # 
  # class NotASubclass
  # end
  # 
  # def test_subclass_raises_error_if_specified_class_is_not_a_subclass_of_task
  #   assert_raise(ArgumentError) { Task.subclass('task_test/not_a_subclass') }
  # end

  #
  # set test
  ### default_name ###

  def test_default_name_is_set_to_name
    subclass.set('name', {}, []) 
    assert_equal "name", subclass.default_name
  end
  
  #
  # set test
  ### configurations ###

  def test_set_adds_configurations_to_subclass
    subclass.set('name', {:key => 'value'}, [])
    assert_equal({:key => 'value'}, subclass.configurations.to_hash)
  
    s = subclass.new
    assert_equal 'value', s.key
  end

  def test_set_adds_or_overrides_specified_configurations_in_subclass
    subclass.set('name', {:key => 'value'}, [])
    assert_equal({:key => 'value'}, subclass.configurations.to_hash)
  
    subclass.set('name', {:another => 'value'}, [])
    assert_equal({:key => 'value', :another => 'value'}, subclass.configurations.to_hash)
    
    subclass.set('name', {:key => 'alt'}, [])
    assert_equal({:key => 'alt', :another => 'value'}, subclass.configurations.to_hash)
  end

  def test_configurations_may_be_specified_as_an_array_of_config_declarations
    config_block = lambda {|input| "value is #{input}" }
    config_attr_block = lambda {|input| @two = "attr value is #{input}" }
  
    configs = [
      [:config, :one, 'value', {}, config_block],
      [:config_attr, :two, 'value', {}, config_attr_block]]
      
    subclass.set('name', configs, [])
    assert_equal({:one => 'value', :two => 'value'}, subclass.configurations.to_hash)
  
    s = subclass.new
    assert_equal 'value is value', s.one
    s.one = 'alt'
    assert_equal 'value is alt', s.one
  
    assert_equal 'attr value is value', s.two
    s.two = 'alt'
    assert_equal 'attr value is alt', s.two
  end

  #
  # set test
  ### dependencies ###

  def test_subclass_defines_or_adds_dependencies_to_subclass
    subclass.set('name', {}, [[:one, Tap::Task]])
    assert_equal([[Tap::Task, []]], subclass.dependencies)
  
    subclass.set('name', {}, [[:two, Tap::Task, [1,2,3]]])
    assert_equal([[Tap::Task, []],[Tap::Task, [1,2,3]]], subclass.dependencies)
  
    s = subclass.new
    assert s.respond_to?(:one)
    assert s.respond_to?(:two)
  end

  #
  # set test
  ### process ###

  def test_block_redefines_process_if_given
    was_in_block = false
    subclass.set('name', {}, []) do
      was_in_block = true
    end
  
    assert !was_in_block
    subclass.new.process
    assert was_in_block
  
    was_in_redefined_block = false
    subclass.set('name', {}, []) do
      was_in_redefined_block = true
    end
  
    assert !was_in_redefined_block
    subclass.new.process
    assert was_in_redefined_block
  end
end