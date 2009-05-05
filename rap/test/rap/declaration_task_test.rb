require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declaration_task'

class DeclarationTaskTest < Test::Unit::TestCase
  include Rap
  
  def teardown
    0.upto(3) do |n|    
      const_name = "Task#{n}".to_sym
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
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

class DeclarationTaskDocTest < Test::Unit::TestCase
  acts_as_file_test
  acts_as_shell_test
  
  RAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
  LOAD_PATHS = [
    "-I'#{RAP_ROOT}/../configurable/lib'",
    "-I'#{RAP_ROOT}/../lazydoc/lib'",
    "-I'#{RAP_ROOT}/../tap/lib'"
  ]
  
  CMD_PATTERN = "% rap"
  CMD = (["TAP_GEMS= ruby"] + LOAD_PATHS + ["'#{RAP_ROOT}/bin/rap'"]).join(" ")
  
  def test_instantiate_doc
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
Rap.task(:a, :obj) {|t, a| puts "A #{a.obj}"}
Rap.task({:b => :a}, :obj) {|t, a| puts "B #{a.obj}"}
}
    end

    method_root.chdir(:tmp) do
      sh_test %q{
% rap b world -- a hello
A hello
B world
}
    end
  end
end