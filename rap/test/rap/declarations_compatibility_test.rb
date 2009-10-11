require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

# many of these tests are patterned after check/rake_check.rb
class DeclarationsCompatibilityTest < Test::Unit::TestCase
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
  
  #
  # compatibility tests
  # 

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
