require File.expand_path('../../rap_test_helper', __FILE__)
require 'rap/declarations'

# used in a resolve_args test
class NeedOne < Tap::Task
end
class NeedTwo < Tap::Task
end

class DeclarationsTest < Test::Unit::TestCase
  include Rap::Declarations
  
  Description = Tap::Declarations::Description
  
  def setup
    env = Tap::Env.new
    app = Tap::App.new({}, :env => env)
    Context.instance.app = app
  end
  
  def teardown
    0.upto(3) do |n|    
      const_name = "Task#{n}".to_sym
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
  end
  
  class Subclass < Rap::Task
  end
  
  #
  # documentation tests
  #
  
  def test_documentation
    assert_equal Rap.task(:sample), Sample.instance(app)
    
    was_in_block = false
    Rap.namespace(:nested) do
      assert_equal Rap.task(:sample), Nested::Sample.instance(app)
      was_in_block = true
    end
    assert was_in_block
    
    desc "task one, a subclass of Rap::Task"
    o = Rap.task(:one)
    assert_equal One, o.class
    assert_equal Rap::Task, o.class.superclass
    assert_equal "task one, a subclass of Rap::Task", o.class.desc.to_s
    
    was_in_block = false
    namespace(:nest) do
  
      desc "task two, a nested subclass of Subclass"
      t = Subclass.task(:two)
      assert_equal Nest::Two, t.class
      assert_equal Subclass, t.class.superclass
      assert_equal "task two, a nested subclass of Subclass", t.class.desc.to_s
      
      was_in_block = true
    end
    assert was_in_block
  end
  
  #
  # interface tests
  #
  
  def test_declaration_API_is_visible_on_Rap
    assert Rap.respond_to?(:namespace)
    assert Rap.respond_to?(:desc)
    assert Rap.respond_to?(:task)
  end
  
  def test_declaration_API_is_hidden_on_Task
    assert Rap::Task.respond_to?(:task)
    assert !Rap::Task.respond_to?(:namespace)
    assert !Rap::Task.respond_to?(:register)
    assert !Rap::Task.respond_to?(:app)
    assert Rap::Task.respond_to?(:instance)
    assert Rap::Task.respond_to?(:desc)
    
    # check instance functionality is as originally declared
    assert context.app.objects.empty?
    assert_equal Rap::Task.instance(context.app), context.app.objects[Rap::Task]
    
    # check desc functionality is as originally declared
    obj = Object.new
    Lazydoc::Document['Rap::Task']['task'] = obj
    assert_equal obj, Rap::Task.desc
  end
  
  #
  # resolve_args test
  #

  def test_resolve_args_resolves_name_configs_dependencies_and_args
    assert_equal ['name', {}, [], []], resolve_args(['name'])
    assert_equal ['name', {:key => 'value'}, [], [:one, :two]], resolve_args([:name, :one, :two, {:key => 'value'}])
    assert_equal ['name', {}, [NeedOne], []], resolve_args([{:name => :need_one}])
    assert_equal ['name', {}, [NeedOne, NeedTwo], []], resolve_args([{:name => ['need_one', :need_two]}])
  end

  def test_resolve_args_yields_to_block_to_lookup_unknown_needs
    assert !Object.const_defined?(:NeedThree)
    
    was_in_block = false
    args = resolve_args([{:name => [:need_three]}]) do |name|
      assert_equal "NeedThree", name
      was_in_block = true
      NeedTwo
    end
    
    assert was_in_block
    assert_equal ['name', {}, [NeedTwo], []], args
  end

  def test_resolve_args_normalizes_names
    assert_equal ['name', {}, [], []], resolve_args([:name])
    assert_equal ['nested/name', {}, [], []], resolve_args(['nested/name'])
    assert_equal ['nested/name', {}, [], []], resolve_args(['nested:name'])
    assert_equal ['nested/name', {}, [], []], resolve_args([:'nested:name'])
  end

  def test_resolve_args_raises_error_if_no_task_name_is_specified
    e = assert_raises(ArgumentError) { resolve_args([]) }
    assert_equal "no task name specified", e.message

    e = assert_raises(ArgumentError) { resolve_args([{}]) }
    assert_equal "no task name specified", e.message
  end

  def test_resolve_args_raises_error_if_multiple_task_names_are_specified
    e = assert_raises(ArgumentError) { resolve_args([{:one => [], :two => []}]) }
    assert e.message =~ /multiple task names specified: \[.*:one.*\]/
    assert e.message =~ /multiple task names specified: \[.*:two.*\]/
  end
  
  def test_nil_needs_are_ignored
    assert_equal ['name', {}, [], []], resolve_args([{:name => [nil, nil, nil]}])
  end
  
  def test_resolve_args_raises_error_needs_cannot_be_resolved
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:need_three]}]) }
    assert_equal "unknown task class: NeedThree", e.message
    
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:need_three]}]) {|name| nil } }
    assert_equal "unknown task class: NeedThree", e.message
  end
  
  def test_resolve_args_raises_error_if_need_is_not_a_task_class
    e = assert_raises(ArgumentError) { resolve_args([{:name => [:object]}]) }
    assert_equal "not a task class: Object", e.message
  end

  #
  # normalize_name test
  #

  def test_normalize_name_documentation
    assert_equal "nested/name", normalize_name('nested:name')
    assert_equal "symbol", normalize_name(:symbol)
  end
  
  #
  # task test
  #
  
  def test_task_subclasses_declaring_class_and_returns_an_instance_of_subclass
    assert !Object.const_defined?(:Task0)
    instance = Rap::Task.task(:task0)
    
    assert_equal Task0, instance.class
    assert_equal self.instance(Task0), instance
    assert_equal Rap::Task, instance.class.superclass
    
    assert !Object.const_defined?(:Task1)
    instance = Subclass.task(:task1)
    
    assert_equal Task1, instance.class
    assert_equal self.instance(Task1), instance
    assert_equal Subclass, instance.class.superclass
  end
  
  def test_task_nests_subclass_in_namespace
    assert !Object.const_defined?(:Task0)
    
    namespace(:task0) do
      namespace(:task1) do
        task(:task2)
      end
    end
    
    assert_equal Rap::Task, Task0::Task1::Task2.superclass
  end
  
  def test_multiple_calls_to_task_with_the_same_name_return_same_instance
    instance_a = task(:task0)
    instance_b = task(:task0)
    assert_equal instance_a.object_id, instance_b.object_id
  end
  
  def test_task_subclass_is_assigned_configurations
    task(:task0, {:key => 'value'})
    assert_equal({:key => 'value'}, Task0.new.config.to_hash)
  end
  
  def test_configs_may_be_added_in_multiple_calls
    task(:task0, {:one => 'one'})
    task(:task0, {:two => 'two'})
    assert_equal({:one => 'one', :two => 'two'}, Task0.instance.config.to_hash)
  end
  
  def test_task_subclass_runs_block_during_process
    was_in_block = false
    task(:task0) do
      was_in_block = true
    end
    
    assert !was_in_block
    Task0.new.process
    assert was_in_block
  end
  
  def test_task_runs_block_for_each_declaration
    was_in_block_a = false
    task(:task0) do
      was_in_block_a = true
    end
    
    was_in_block_b = false
    task(:task0) do
      was_in_block_b = true
    end
    
    assert !was_in_block_a
    assert !was_in_block_b
    Task0.new.process
    assert was_in_block_a
    assert was_in_block_b
  end
  
  def test_task_subclass_sets_dependencies_using_initial_hash_if_given
    task(:task0 => Subclass)
    assert_equal [Subclass], Task0.dependencies
    
    instance = task(:task1 => [Subclass, Rap::Task])
    assert_equal [Subclass, Rap::Task], Task1.dependencies
  end
  
  def test_tasks_for_undefined_dependencies_are_generated_by_task
    task(:task0 => :task1)
    assert_equal [Task1], Task0.dependencies
  end
  
  def test_task_dependencies_may_be_added_in_multiple_calls
    task(:task0 => :task1)
    task(:task0 => :task2)
  
    assert_equal [Task1, Task2], Task0.dependencies
  end
  
  def test_task_does_not_add_duplicate_dependencies
    task(:task0 => [:task1])
    task(:task0 => [:task1])
    task(:task0 => [:task1, :task1])
  
    assert_equal [Task1], Task0.dependencies
  end
  
  def test_namespaces_are_resolved_in_dependencies
    begin
      assert !Object.const_defined?("Existant")
      assert !Object.const_defined?("NonExistant")
      assert !Object.const_defined?("ExistantNest")
      assert !Object.const_defined?("NonExistantNest")
      assert !Object.const_defined?("Ref")
      
      task(:existant)
      namespace(:existant_nest) do
        # reference an existant, non-nested task
        task(:existant => 'existant')
      
        # reference a non-existant non-nested task
        task(:existant => 'non_existant')
      end
    
      task(:ref => 'existant')
      task(:ref => 'non_existant')
      task(:ref => 'existant_nest:existant')
      task(:ref => 'existant_nest:non_existant_task')
      task(:ref => 'non_existant_nest:non_existant_task')
    
      assert_equal [
        Existant, 
        NonExistant, 
        ExistantNest::Existant, 
        ExistantNest::NonExistantTask, 
        NonExistantNest::NonExistantTask
      ], Ref.dependencies
    
      assert_equal [
        Existant, 
        NonExistant
      ], ExistantNest::Existant.dependencies
    ensure
      Object.send(:remove_const, "Existant") if Object.const_defined?("Existant")
      Object.send(:remove_const, "NonExistant") if Object.const_defined?("NonExistant")
      Object.send(:remove_const, "ExistantNest") if Object.const_defined?("ExistantNest")
      Object.send(:remove_const, "NonExistantNest") if Object.const_defined?("NonExistantNest")
      Object.send(:remove_const, "Ref") if Object.const_defined?("Ref")
    end
  end
  
  def test_task_registers_documentation
    # :: summary
    # a multiline
    # comment
    task(:task0)
  
    Lazydoc[__FILE__].resolved = false
    assert_equal Description, Task0.desc.class
    assert_equal "summary", Task0.desc.to_s
    assert_equal "a multiline comment", Task0.desc.comment
  
    # a comment with no
    # description
    task(:task1)
  
    Lazydoc[__FILE__].resolved = false
    assert_equal "", Task1.desc.to_s
    assert_equal "a comment with no description", Task1.desc.comment
  end
  
  def test_multiple_calls_to_task_reassigns_documentation
    # :: summary
    # comment
    task(:task0)
  
    # :: new summary
    # new comment
    task(:task0)
  
    Lazydoc[__FILE__].resolved = false
    assert_equal Description, Task0.desc.class
    assert_equal "new summary", Task0.desc.to_s
    assert_equal "new comment", Task0.desc.comment
  end
end
