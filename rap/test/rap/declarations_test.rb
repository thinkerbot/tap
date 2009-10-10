require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class NeedOne < Tap::Task
end
class NeedTwo < Tap::Task
end

class DeclarationsTest < Test::Unit::TestCase
  include Rap::Declarations
  
  def setup
    env = Tap::Env.new
    app = Tap::App.new(:env => env)
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
  
  class Alt < Rap::Task
  end
  
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
  
      desc "task two, a nested subclass of Alt"
      t = Alt.task(:two)
      assert_equal Nest::Two, t.class
      assert_equal Alt, t.class.superclass
      assert_equal "task two, a nested subclass of Alt", t.class.desc.to_s
      
      was_in_block = true
    end
    assert was_in_block
  end
  
  #
  # interface tests
  #
  
  module IncludingModule
    include Rap::Declarations
  end
  
  def test_declaration_API_is_hidden_on_including_modules
    assert !IncludingModule.respond_to?(:namespace)
    assert !IncludingModule.respond_to?(:desc)
    assert !IncludingModule.respond_to?(:register)
  end
  
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
    assert context.app.cache.empty?
    assert_equal Rap::Task.instance(context.app), context.app.cache[Rap::Task]
    
    # check desc functionality is as originally declared
    obj = Object.new
    Lazydoc::Document['Rap::Task']['task'] = obj
    assert_equal obj, Rap::Task.desc
  end
  
  #
  # task test
  #
  
  def test_task_returns_a_subclass_of_self
    assert_equal Rap::Task, Rap::Task.task(:task0).class.superclass
    assert_equal Subclass, Subclass.task(:task1).class.superclass
  end
  
  #
  # resolve_args test
  #

  def test_resolve_args
    assert_equal ['name', {}, [], []], resolve_args(['name'])
    assert_equal ['name', {:key => 'value'}, [], [:one, :two]], resolve_args([:name, :one, :two, {:key => 'value'}])
  end
  
  def test_resolve_args_looks_up_needs
    assert_equal ['name', {}, [NeedOne], []], resolve_args([{:name => :need_one}])
    assert_equal ['name', {}, [NeedOne, NeedTwo], []], resolve_args([{:name => [:need_one, :need_two]}])
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
  # task declaration
  #
  
  def test_task_generates_a_class_dependency_instance
    assert !Object.const_defined?(:Task0)
    
    instance = task(:task0)
    assert_equal Task0, instance.class
    assert_equal self.instance(Task0), instance
    assert_equal Rap::Task, Task0.superclass
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
    assert_equal instance_a, instance_b
  end
  
  def test_task_subclass_is_assigned_configurations
    task(:task0, {:key => 'value'})
    assert_equal({:key => 'value'}, Task0.new.config.to_hash)
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
  
  def test_task_subclass_sets_dependencies_using_initial_hash_if_given
    task(:task0 => Subclass)
    assert_equal [Subclass], Task0.dependencies
    
    instance = task(:task1 => [Subclass, Rap::Task])
    assert_equal [Subclass, Rap::Task], Task1.dependencies
  end
  
  def test_undefined_dependencies_are_resolved_into_tasks_using_declare
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
  
  def test_task_registers_documentation
    # ::desc summary
    # a multiline
    # comment
    task(:task0)
  
    Lazydoc[__FILE__].resolved = false
    assert_equal Rap::Description, Task0.desc.class
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
    # ::desc summary
    # comment
    task(:task0)
  
    # ::desc new summary
    # new comment
    task(:task0)
  
    Lazydoc[__FILE__].resolved = false
    assert_equal Rap::Description, Task0.desc.class
    assert_equal "new summary", Task0.desc.to_s
    assert_equal "new comment", Task0.desc.comment
  end
  
  #
  # rake compatibility tests
  # 
  # many of these tests are patterned after check/rake_check.rb
  
  def test_task_returns_instance_of_subclass
    result = task(:task0)
    assert_equal instance(Task0), result 
  end
  
  def test_task_chains_block_to_subclass_actions
    results = []
    block_one = lambda { results << 1 }
    block_two = lambda { results << 2 }
  
    t = task(:task0, &block_one)
    t.process
    assert_equal [1], results
  
    results.clear
  
    t = task(:task0, &block_two)
    t.process
    assert_equal [1,2], results
  end
  
  def test_task_supports_dependencies_like_rake
    runlist = []
  
    a = task(:task0) {|t| runlist << t }
    b = task(:task1 => [:task0])  {|t| runlist << t }
    c = task(:task2 => :task1)  {|t| runlist << t }
  
    c.execute
    assert_equal [a,b,c], runlist
  end
  
  def test_task_supports_rake_args_declaration
    arg_hash = nil
    t = task(:task0, :one, :two, :three) do |task, args|
      arg_hash = args.marshal_dump
    end
  
    t.process('1', '2', '3')
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
  
  def test_task_args_declaration_with_too_few_args_uses_nil
    arg_hash = nil
    t = task(:task0, :one, :two, :three) do |task, args|
      arg_hash = args.marshal_dump
    end
  
    t.process('1','2')
    assert_equal({:one => '1', :two => '2'}, arg_hash)
  end
  
  def test_task_args_declaration_with_too_many_args_ignores_extra_args
    arg_hash = nil
    t = task(:task0, :one, :two, :three) do |task, args|
      arg_hash = args.marshal_dump
    end
  
    t.process('1','2','3','4')
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
  
  def test_task_args_declaration_will_override_with_later_args
    arg_hash_a = nil
    t = task(:task0, :one, :two, :three) do |task, args|
      arg_hash_a = args.marshal_dump
    end
  
    arg_hash_b = nil
    t1 = task(:task0, :four, :five) do |task, args|
      arg_hash_b = args.marshal_dump
    end
  
    t1.process('1','2','3','4','5')
    assert_equal({:four => '1', :five => '2'}, arg_hash_a)
    assert_equal({:four => '1', :five => '2'}, arg_hash_b)
  end
  
  def test_task_args_declaration_will_override_with_later_args_when_no_later_args_are_given
    arg_hash_a = nil
    t = task(:task0, :one, :two, :three) do |task, args|
      arg_hash_a = args.marshal_dump
    end
  
    arg_hash_b = nil
    t1 = task(:task0) do |task, args|
      arg_hash_b = args.marshal_dump
    end
  
    t1.process('1','2','3','4','5')
    assert_equal({}, arg_hash_a)
    assert_equal({}, arg_hash_b)
  end
  
  def test_task_declarations_with_namespace
    str = ""
    task(:task0) { str << 'a' }
  
    namespace :task0 do
      task(:task1) { str << 'b' }
    end
  
    t = task(:task2 => [:task0, 'task0:task1'])
    task(:task2) { str << 'c' }
    task(:task2) { str << '!' }
  
    t.execute
    assert_equal "abc!", str
  end
  
  def test_task_declarations_with_same_name_namespaces
    str = ""
    task(:task0) { str << 'a1' }
  
    namespace :task0 do
      task(:task1) { str << 'b1' }
    end
  
    namespace :task1 do
      task(:task0) { str << 'a2' }
    end
  
    task(:task1) { str << 'b2' }
  
    t = task(:task2 => ['task0', 'task0:task1', 'task1:task0', 'task1'])
  
    t.execute
    assert_equal "a1b1a2b2", str
  end
  
  def test_namespaces_are_a_less_crazy_than_rake
    arr = []
    task(:outer1) { arr << 'outer1' }
    task(:outer2) { arr << 'outer2' }
    
    namespace :nest do
      task(:inner1 => :outer1) { arr << 'inner1' }
      
      # outer2 defined in nest
      task(:inner2 => :outer2) { arr << 'inner2' }
      task(:outer2) { arr << 'inner3' }
    end
    
    instance(::Nest::Inner1).execute
    instance(::Nest::Inner2).execute
    
    # this is the rake output
    #assert_equal ["outer1", "inner1", "inner3", "inner2"], arr
    assert_equal ["outer1", "inner1", "outer2", "inner2"], arr
  end
end
