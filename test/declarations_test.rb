require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/declarations'

class DeclarationsTest < Test::Unit::TestCase
  include Tap::Declarations
  
  def setup
    @declaration_base = "DeclarationsTest"
    @env = Tap::Env.instance_for(File.dirname(__FILE__))
  end
  
  #
  # tasc declaration
  #
  
  def test_tasc_generates_subclass_of_Task_by_name
    assert !DeclarationsTest.const_defined?(:Tasc0)
    klass = tasc(:tasc0)
    assert_equal DeclarationsTest::Tasc0, klass
    assert_equal Tap::Task, klass.superclass
  end
  
  def test_multiple_calls_to_tasc_with_the_same_name_return_same_class
    klass_a = tasc(:tasc1)
    klass_b = tasc(:tasc1)
    assert_equal klass_a, klass_b
  end
  
  def test_tasc_subclass_is_assigned_configurations
    tasc(:tasc2, {:key => 'value'})
    assert_equal({:key => 'value'}, Tasc2.configurations.to_hash)
  end
  
  def test_tasc_subclass_sets_block_as_process
    was_in_block = false
    tasc(:tasc3) do
      was_in_block = true
    end
    
    assert !was_in_block
    Tasc3.new.process
    assert was_in_block
  end
  
  def test_tasc_subclass_sets_dependencies_using_initial_hash_if_given
    tasc(:tasc4 => [Tap::Task])
    assert_equal [
      [Tap::Task, []]
    ], Tasc4.dependencies
    
    tasc(:tasc5 => [Tap::Task, [Tap::FileTask, [1,2,3]]])
    assert_equal [
      [Tap::Task, []], 
      [Tap::FileTask, [1,2,3]]
    ], Tasc5.dependencies
  end
  
  def test_tasc_sym_dependencies_are_resolved_into_tasks_using_declare
    tasc(:tasc8 => [:tasc6, [:tasc7, [1,2,3]]])
    assert_equal [
      [Tasc6, []],
      [Tasc7, [1,2,3]]
    ], Tasc8.dependencies
  end
  
  def test_tasc_dependencies_may_be_added_in_multiple_calls
    tasc(:tasc10 => [:tasc9])
    tasc(:tasc10 => [[:tasc9, [1,2,3]]])

    assert_equal [
      [Tasc9, []],
      [Tasc9, [1,2,3]]
    ], Tasc10.dependencies
  end
  
  def test_tasc_does_not_add_duplicate_dependencies
    tasc(:tasc12 => [:tasc11])
    tasc(:tasc12 => [:tasc11])
    tasc(:tasc12 => [:tasc11, :tasc11])
    tasc(:tasc12 => [[:tasc11, [1,2,3]]])
    tasc(:tasc12 => [[:tasc11, [1,2,3]]])
    tasc(:tasc12 => [[:tasc11, [1,2,3]], [:tasc11, [1,2,3]]])

    assert_equal [
      [Tasc11, []],
      [Tasc11, [1,2,3]]
    ], Tasc12.dependencies
  end
  
  def test_tasc_registers_documentation
    # ::desc summary
    # a multiline
    # comment
    tasc(:tasc13)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal Tap::Support::Lazydoc::Declaration, Tasc13.manifest.class
    assert_equal "summary", Tasc13.manifest.subject
    assert_equal "a multiline comment", Tasc13.manifest.to_s
    
    # a comment with no
    # description
    tasc(:tasc14)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal "", Tasc14.manifest.subject
    assert_equal "a comment with no description", Tasc14.manifest.to_s
  end
  
  def test_multiple_calls_to_tasc_reassigns_documentation
    # ::desc summary
    # comment
    tasc(:tasc15)
    
    # ::desc new summary
    # new comment
    tasc(:tasc15)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal Tap::Support::Lazydoc::Declaration, Tasc15.manifest.class
    assert_equal "new summary", Tasc15.manifest.subject
    assert_equal "new comment", Tasc15.manifest.to_s
  end
  
  #
  # tasc nesting
  #
  
  module Nest
    extend Tap::Declarations
    c = tasc(:nested_sample) {}
  end
 
  def test_declarations_nest_constant
    const = tasc(:nested_sample)
    assert_equal "DeclarationsTest::NestedSample", const.to_s
    
    assert Nest.const_defined?("NestedSample")
  end
  
  def test_declarations_are_not_nested_for_rap
    const = Tap.tasc(:sample_declaration)
    assert_equal "SampleDeclaration", const.to_s
  end

  #
  # task declaration
  #
  
  def test_task_generates_instance_of_subclass_of_Task_by_name
    assert !DeclarationsTest.const_defined?(:Task0)
    instance = task(:task0)
    assert_equal DeclarationsTest::Task0, instance.class
    assert_equal Task0.instance, instance
    assert_equal Tap::Task, Task0.superclass
  end
  
  def test_multiple_calls_to_task_with_the_same_name_return_same_instance
    instance_a = task(:task1)
    instance_b = task(:task1)
    assert_equal instance_a, instance_b
  end
  
  def test_task_subclass_is_assigned_configurations
    task(:task2, {:key => 'value'})
    assert_equal({:key => 'value'}, Task2.configurations.to_hash)
  end
  
  def test_task_subclass_runs_block_during_process
    was_in_block = false
    task(:task3) do
      was_in_block = true
    end
    
    assert !was_in_block
    Task3.new.process
    assert was_in_block
  end
  
  def test_task_subclass_sets_dependencies_using_initial_hash_if_given
    task(:task4 => [Tap::Task])
    assert_equal [
      [Tap::Task, []]
    ], Task4.dependencies
    
    instance = task(:task5 => [Tap::Task, [Tap::FileTask, [1,2,3]]])
    assert_equal [
      [Tap::Task, []], 
      [Tap::FileTask, [1,2,3]]
    ], Task5.dependencies
  end
  
  def test_task_sym_dependencies_are_resolved_into_tasks_using_declare
    task(:task8 => [:task6, [:task7, [1,2,3]]])
    assert_equal [
      [Task6, []],
      [Task7, [1,2,3]]
    ], Task8.dependencies
  end
  
  def test_task_dependencies_may_be_added_in_multiple_calls
    task(:task10 => [:task9])
    task(:task10 => [[:task9, [1,2,3]]])

    assert_equal [
      [Task9, []],
      [Task9, [1,2,3]]
    ], Task10.dependencies
  end
  
  def test_task_does_not_add_duplicate_dependencies
    task(:task12 => [:task11])
    task(:task12 => [:task11])
    task(:task12 => [:task11, :task11])
    task(:task12 => [[:task11, [1,2,3]]])
    task(:task12 => [[:task11, [1,2,3]]])
    task(:task12 => [[:task11, [1,2,3]], [:task11, [1,2,3]]])

    assert_equal [
      [Task11, []],
      [Task11, [1,2,3]]
    ], Task12.dependencies
  end
  
  def test_task_registers_documentation
    # ::desc summary
    # a multiline
    # comment
    task(:task13)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal Tap::Support::Lazydoc::Declaration, Task13.manifest.class
    assert_equal "summary", Task13.manifest.subject
    assert_equal "a multiline comment", Task13.manifest.to_s
    
    # a comment with no
    # description
    task(:task14)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal "", Task14.manifest.subject
    assert_equal "a comment with no description", Task14.manifest.to_s
  end
  
  def test_multiple_calls_to_task_reassigns_documentation
    # ::desc summary
    # comment
    task(:task15)
    
    # ::desc new summary
    # new comment
    task(:task15)
    
    Tap::Support::Lazydoc[__FILE__].resolved = false
    assert_equal Tap::Support::Lazydoc::Declaration, Task15.manifest.class
    assert_equal "new summary", Task15.manifest.subject
    assert_equal "new comment", Task15.manifest.to_s
  end
  
  #
  # rake compatibility tests
  # 
  # many of these tests are patterned after check/rake_check.rb
  
  def test_task_returns_instance_of_subclass
    result = task(:rake2)
    assert_equal Rake2.instance, result 
  end
  
  def test_task_chains_block_to_subclass_actions
    results = []
    block_one = lambda { results << 1 }
    block_two = lambda { results << 2 }
    
    t = task(:rake3, &block_one)
    t.process
    assert_equal [1], results
    
    results.clear
    
    t = task(:rake3, &block_two)
    t.process
    assert_equal [1,2], results
  end
  
  def test_task_supports_dependencies_like_rake
    runlist = []
    
    a = task(:a) {|t| runlist << t }
    b = task(:b => [:a])  {|t| runlist << t }
    c = task(:c => :b)  {|t| runlist << t }
    
    c._execute
    assert_equal [a,b,c], runlist
  end
  
  def test_task_supports_rake_args_declaration
    arg_hash = nil
    x = task(:x, :one, :two, :three) do |t, args|
      arg_hash = args.marshal_dump
    end
    
    x.process('1', '2', '3')
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
  
  def test_task_args_declaration_with_too_few_args_uses_nil
    arg_hash = nil
    y = task(:y, :one, :two, :three) do |t, args|
      arg_hash = args.marshal_dump
    end
    
    y.process('1','2')
    assert_equal({:one => '1', :two => '2'}, arg_hash)
  end
  
  def test_task_args_declaration_with_too_many_args_ignores_extra_args
    arg_hash = nil
    z = task(:z, :one, :two, :three) do |t, args|
      arg_hash = args.marshal_dump
    end
    
    z.process('1','2','3','4')
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
    
  def test_task_args_declaration_will_override_with_later_args
    arg_hash_a = nil
    p = task(:p, :one, :two, :three) do |t, args|
      arg_hash_a = args.marshal_dump
    end
    
    arg_hash_b = nil
    p1 = task(:p, :four, :five) do |t, args|
      arg_hash_b = args.marshal_dump
    end

    p1.process('1','2','3','4','5')
    assert_equal({:four => '1', :five => '2'}, arg_hash_a)
    assert_equal({:four => '1', :five => '2'}, arg_hash_b)
  end
  
  def test_task_args_declaration_will_override_with_later_args_when_no_later_args_are_given
    arg_hash_a = nil
    q = task(:q, :one, :two, :three) do |t, args|
      arg_hash_a = args.marshal_dump
    end
    
    arg_hash_b = nil
    q1 = task(:q) do |t, args|
      arg_hash_b = args.marshal_dump
    end

    q1.process('1','2','3','4','5')
    assert_equal({}, arg_hash_a)
    assert_equal({}, arg_hash_b)
  end
end