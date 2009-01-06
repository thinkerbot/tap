require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class DeclarationsTest < Test::Unit::TestCase
  include Rap::Declarations
  
  def setup
    @declaration_base = "DeclarationsTest"
    @env = Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
  end
  
  #
  # task nesting
  #
  
  module Nest
    extend Rap::Declarations
    task(:nested_sample)
  end
   
  def test_declarations_nest_constant
    t = task(:nested_sample)
    assert_equal "DeclarationsTest::NestedSample", t.class.to_s
    
    assert Nest.const_defined?("NestedSample")
  end
  
  def test_declarations_are_not_nested_for_rap
    t = Rap.task(:sample_declaration)
    assert_equal "SampleDeclaration", t.class.to_s
  end
  
  #
  # task declaration
  #
  
  def test_task_generates_instance_of_subclass_of_Task_by_name
    assert !DeclarationsTest.const_defined?(:Task0)
    instance = task(:task0)
    assert_equal DeclarationsTest::Task0, instance.class
    assert_equal Task0.instance, instance
    assert_equal Rap::DeclarationTask, Task0.superclass
  end
  
  def test_multiple_calls_to_task_with_the_same_name_return_same_instance
    instance_a = task(:task1)
    instance_b = task(:task1)
    assert_equal instance_a, instance_b
  end
  
  def test_task_subclass_is_assigned_configurations
    task(:task2, {:key => 'value'})
    assert_equal({:key => 'value'}, Task2.new.config.to_hash)
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
    task(:task4 => Tap::Task)
    assert_equal [Tap::Task], Task4.dependencies
    
    instance = task(:task5 => [Tap::Task, Tap::FileTask])
    assert_equal [Tap::Task, Tap::FileTask], Task5.dependencies
  end
  
  def test_task_sym_dependencies_are_resolved_into_tasks_using_declare
    task(:task7 => :task6)
    assert_equal [Task6], Task7.dependencies
  end
  
  def test_task_dependencies_may_be_added_in_multiple_calls
    task(:task10 => :task8)
    task(:task10 => :task9)
  
    assert_equal [Task8, Task9], Task10.dependencies
  end
  
  def test_task_does_not_add_duplicate_dependencies
    task(:task12 => [:task11])
    task(:task12 => [:task11])
    task(:task12 => [:task11, :task11])

    assert_equal [Task11], Task12.dependencies
  end
  
  def test_task_registers_documentation
    # ::desc summary
    # a multiline
    # comment
    task(:task13)

    Lazydoc[__FILE__].resolved = false
    assert_equal Rap::Description, Task13.manifest.class
    assert_equal "summary", Task13.manifest.to_s
    assert_equal "a multiline comment", Task13.manifest.comment

    # a comment with no
    # description
    task(:task14)

    Lazydoc[__FILE__].resolved = false
    assert_equal "", Task14.manifest.to_s
    assert_equal "a comment with no description", Task14.manifest.comment
  end

  def test_multiple_calls_to_task_reassigns_documentation
    # ::desc summary
    # comment
    task(:task15)

    # ::desc new summary
    # new comment
    task(:task15)

    Lazydoc[__FILE__].resolved = false
    assert_equal Rap::Description, Task15.manifest.class
    assert_equal "new summary", Task15.manifest.to_s
    assert_equal "new comment", Task15.manifest.comment
  end
  
  #
  # resolve_args test
  #
  
  def test_resolve_args
    assert_equal ['name', {}, [], []], resolve_args(['name'])
    assert_equal ['name', {:key => 'value'}, [], [:one, :two]], resolve_args([:name, :one, :two, {:key => 'value'}])
  end
  
  class NeedOne < Rap::DeclarationTask
  end
  class NeedTwo < Rap::DeclarationTask
  end
  
  def test_resolve_args_looks_up_needs
    assert_equal ['name', {}, [NeedOne], []], resolve_args([{:name => :need_one}])
    assert_equal ['name', {}, [NeedOne, NeedTwo], []], resolve_args([{:name => [:need_one, :need_two]}])
  end
  
  def test_resolve_args_defines_task_class_for_unknown_needs
    assert !DeclarationsTest.const_defined?(:NeedThree)
    args = resolve_args([{:name => [:need_three]}])
    
    assert DeclarationsTest.const_defined?(:NeedThree)
    assert Rap::DeclarationTask, NeedThree.superclass
    assert_equal ['name', {}, [NeedThree], []], args
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
  
  #
  # normalize_name test
  #
  
  def test_normalize_name_documentation
    assert_equal "nested/name", normalize_name('nested:name')
    assert_equal "symbol", normalize_name(:symbol)
  end
  
  #
  # declare test
  #
  
  class NonDeclarationTask
  end
  
  def test_declare_raises_error_if_it_looks_up_a_non_DeclarationTask_class
    e = assert_raises(RuntimeError) { declare(:NonDeclarationTask) }
    assert_equal "not a DeclarationTask: DeclarationsTest::NonDeclarationTask", e.message
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

    c.execute
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

  def test_task_declarations_with_namespace
    str = ""
    task(:p) { str << 'a' }

    namespace :p do
      task(:q) { str << 'b' }
    end

    c = task(:r => [:p, 'p:q'])
    task(:r) { str << 'c' }
    task(:r) { str << '!' }

    c.execute
    assert_equal "abc!", str
  end

  def test_task_declarations_with_same_name_namespaces
    str = ""
    task(:aa) { str << 'a1' }

    namespace :aa do
      task(:bb) { str << 'b1' }
    end

    namespace :bb do
      task(:aa) { str << 'a2' }
    end

    task(:bb) { str << 'b2' }

    cc = task(:cc => ['aa', 'aa:bb', 'bb:aa', 'bb'])

    cc.execute
    assert_equal "a1b1a2b2", str
  end
  
  def test_namespaces_are_a_less_crazy_than_rake
    arr = []
    Rap.task(:outer1) { arr << 'outer1' }
    Rap.task(:outer2) { arr << 'outer2' }
    
    Rap.namespace :nest do
      Rap.task(:inner1 => :outer1) { arr << 'inner1' }
      
      # outer2 defined in nest
      Rap.task(:inner2 => :outer2) { arr << 'inner2' }
      Rap.task(:outer2) { arr << 'inner3' }
    end
    
    ::Nest::Inner1.instance.execute
    ::Nest::Inner2.instance.execute
    
    # this is the rake output
    #assert_equal ["outer1", "inner1", "inner3", "inner2"], arr
    assert_equal ["outer1", "inner1", "outer2", "inner2"], arr
  end
end