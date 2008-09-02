require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'

# used in documentation test
class ConfiguredTask < Tap::Task
  config :one, 'one'
  config :two, 'two'
end

class ValidatingTask < Tap::Task
  config :string, 'str', &c.check(String)
  config :integer, 1, &c.yaml(Integer)
end 

class SubclassTask < Tap::Task
  attr_accessor :array
  def initialize(*args)
    @array = []
    super
  end

  def initialize_copy(orig)
    @array = orig.array.dup
    super
  end
end

class TaskTest < Test::Unit::TestCase
  include Tap
  include TapTestMethods
  
  acts_as_tap_test
  attr_accessor :t
  
  def setup
    super
    @t = Task.new
    app.root = trs.root
  end
  
  # sample class repeatedly used in tests
  class Sample < Tap::Task
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end
  
  #
  # documentation test
  #
  
  def test_documentation
    t = ConfiguredTask.new
    assert_equal("configured_task", t.name)
    assert_equal({:one => 'one', :two => 'two'}, t.config)           
  
    t = ValidatingTask.new
    assert_raise(Support::Validation::ValidationError) { t.string = 1 }
    assert_raise(Support::Validation::ValidationError) { t.integer = 1.1 }
  
    t.integer = "1"
    assert_equal 1, t.integer
    
    t = ConfiguredTask.new({:one => 'ONE', :three => 'three'}, "example")
    assert_equal "example", t.name
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, t.config)
    
    ###
    app = Tap::App.instance
    t1 = Tap::Task.new(:key => 'one') do |task, input| 
      input + task.config[:key]
    end
    assert_equal [t1], t1.batch
  
    t2 = t1.initialize_batch_obj(:key => 'two')
    assert_equal [t1, t2], t1.batch
    assert_equal [t1, t2], t2.batch
    
    t1.enq 't1_by_'
    t2.enq 't2_by_'
    app.run
  
    assert_equal ["t1_by_one", "t2_by_one"], app.results(t1)
    assert_equal ["t1_by_two", "t2_by_two"], app.results(t2)
    
    ###
    t1 = SubclassTask.new
    t2 = t1.initialize_batch_obj
    assert_equal true, t1.array == t2.array
    assert_equal false, t1.array.object_id == t2.array.object_id
  end
  
  #
  # Task.source_file test
  #
  
  def test_source_file_is_set_to_file_where_subclass_first_inherits_Task
    assert_equal File.expand_path(__FILE__), Sample.source_file
  end

  #
  # Task.default_name test
  #
  
  class NameClass < Tap::Task
    class NestedClass < Tap::Task
    end
  end
  
  def test_default_name_is_underscored_class_name_by_default
    assert_equal "task_test/name_class", NameClass.default_name
    assert_equal "task_test/name_class/nested_class", NameClass::NestedClass.default_name
  end
  
  #
  # Task.instance test
  #
  
  def test_instance_returns_class_level_instance
    i = Task.instance
    assert_equal Task, i.class
    assert_equal i, Task.instance 
  end
  
  #
  # Task.dependencies test
  #
  
  def test_dependencies_are_empty_by_default
    assert_equal [], Task.dependencies
  end

  #
  # Task.depends_on test
  #
  
  class DependencyClass < Tap::Task
  end
  
  class DependentClass < Tap::Task
    depends_on DependencyClass
    depends_on DependencyClass, 1,2,3
  end
  
  def test_depends_on_adds_dependency_class_with_args_to_dependencies
    assert_equal [
      [DependencyClass, []], 
      [DependencyClass, [1,2,3]]
    ], DependentClass.dependencies
  end
  
  def test_depends_on_raises_error_if_dependency_class_does_not_respond_to_instance
    assert_raise(ArgumentError) { DependentClass.depends_on(Object) }
    assert_raise(ArgumentError) { DependentClass.depends_on(Object.new) }
  end
  
  def test_depends_on_returns_self
    assert_equal DependentClass, DependentClass.depends_on(DependencyClass)
  end
  
  class DependentDupClass < Tap::Task
    depends_on DependencyClass
    depends_on DependencyClass, 1,2,3
    
    depends_on DependencyClass
    depends_on DependencyClass, 1,2,3
  end
  
  def test_depends_on_removes_duplicates
    assert_equal [
      [DependencyClass, []], 
      [DependencyClass, [1,2,3]]
    ], DependentDupClass.dependencies
  end
  
  class DependentParentClass < Tap::Task
    depends_on DependencyClass
  end
  
  class DependentSubClass < DependentParentClass
    depends_on DependencyClass, 1,2,3
  end
  
  def test_dependencies_are_inherited_down_but_not_up
    assert_equal [
      [DependencyClass, []]
    ], DependentParentClass.dependencies
    
    assert_equal [
      [DependencyClass, []], 
      [DependencyClass, [1,2,3]]
    ], DependentSubClass.dependencies
  end

  #
  # Task.dependency test
  #
  
  class DependenyDeclaration < Tap::Task
    dependency :dep, DependencyClass, 1,2,3
  end
  
  def test_dependency_makes_a_reader_for_the_results_of_the_dependency
    d = DependenyDeclaration.new
    assert d.respond_to?(:dep)
    
    d.resolve_dependencies
    assert_equal [1,2,3], d.dep
  end
  
  def test_dependency_reader_resolves_dependencies_if_needed
    d = DependenyDeclaration.new
    assert_equal [1,2,3], d.dep
  end

  #
  # Task.subclass test
  #
  
  module Subclass
  end

  ### constants  ###
  
  def test_subclass_generates_subclass_of_Task_by_name
    assert !Subclass.const_defined?(:One)
    subclass = Task.subclass('task_test/subclass/one')
    assert_equal Subclass::One, subclass
    assert_equal Task, subclass.superclass
  end
  
  def test_subclasses_can_generate_subclasses
    assert !Subclass.const_defined?(:TwoA)
    subclass_a = Task.subclass('task_test/subclass/two_a')
    subclass_b = subclass_a.subclass('task_test/subclass/two_b')
    
    assert_equal Subclass::TwoA, subclass_a
    assert_equal Subclass::TwoB, subclass_b
    assert_equal subclass_a, subclass_b.superclass
  end
  
  def test_subclass_generates_modules_as_needed
    assert !Subclass.const_defined?(:Nested)
    subclass = Task.subclass('task_test/subclass/nested/one')
    assert_equal Subclass::Nested::One, subclass
  end
  
  def test_subclass_generates_subclass_in_Object
    assert !Subclass.const_defined?(:Three)
    subclass = Task.subclass('object/task_test/subclass/three')
    assert_equal Subclass::Three, subclass
  end
  
  class ExistingSubclass < Tap::Task
  end
  
  def test_subclass_returns_existing_subclass
    assert_equal ExistingSubclass, Task.subclass('task_test/existing_subclass')
  end
  
  class NotASubclass
  end
  
  def test_subclass_raises_error_if_specified_class_is_not_a_subclass_of_task
    assert_raise(ArgumentError) { Task.subclass('task_test/not_a_subclass') }
  end
  
  ### configurations ###
  
  def test_subclass_defines_subclass_with_specified_configurations
    subclass = Task.subclass('task_test/subclass/four', :key => 'value')
    assert_equal({:key => 'value'}, subclass.configurations.to_hash)
    
    s = subclass.new
    assert_equal 'value', s.key
  end
  
  def test_subclass_adds_or_overrides_specified_configurations_to_subclass
    subclass = Task.subclass('task_test/subclass/five', :key => 'value')
    assert_equal({:key => 'value'}, subclass.configurations.to_hash)
    
    subclass = Task.subclass('task_test/subclass/five', :another => 'value')
    assert_equal({:key => 'value', :another => 'value'}, subclass.configurations.to_hash)
    
    subclass = Task.subclass('task_test/subclass/five', :key => 'alt')
    assert_equal({:key => 'alt', :another => 'value'}, subclass.configurations.to_hash)
  end
  
  def test_configurations_may_be_specified_as_an_array_of_config_declarations
    config_block = lambda {|input| "value is #{input}" }
    config_attr_block = lambda {|input| @two = "attr value is #{input}" }
    
    subclass = Task.subclass('task_test/subclass/six', [
      [:config, :one, 'value', {}, config_block],
      [:config_attr, :two, 'value', {}, config_attr_block]])
    assert_equal({:one => 'value', :two => 'value'}, subclass.configurations.to_hash)
    
    s = subclass.new
    assert_equal 'value is value', s.one
    s.one = 'alt'
    assert_equal 'value is alt', s.one
    
    assert_equal 'attr value is value', s.two
    s.two = 'alt'
    assert_equal 'attr value is alt', s.two
  end
  
  ### dependencies ###
  
  def test_subclass_defines_or_adds_dependencies_to_subclass
    subclass = Task.subclass('task_test/subclass/seven', {}, [[:one, Tap::Task]])
    assert_equal([[Tap::Task, []]], subclass.dependencies)
    
    subclass = Task.subclass('task_test/subclass/seven', {}, [[:two, Tap::Task, [1,2,3]]])
    assert_equal([[Tap::Task, []],[Tap::Task, [1,2,3]]], subclass.dependencies)
    
    s = subclass.new
    assert s.respond_to?(:one)
    assert s.respond_to?(:two)
  end
  
  ### process ###
  
  def test_block_redefines_process_if_given
    was_in_block = false
    subclass = Task.subclass('task_test/subclass/nine') do
      was_in_block = true
    end
    
    assert !was_in_block
    subclass.new.process
    assert was_in_block
    
    was_in_redefined_block = false
    subclass = Task.subclass('task_test/subclass/nine') do
      was_in_redefined_block = true
    end
    
    assert !was_in_redefined_block
    subclass.new.process
    assert was_in_redefined_block
  end
  
  ### default_name ###
  
  def test_default_name_is_set_to_name
    subclass = Task.subclass('task_test/subclass/ten')
    assert_equal "task_test/subclass/ten", subclass.default_name
  end
  
  def test_default_name_ignores_Object_if_specified
    subclass = Task.subclass('object/task_test/subclass/eleven')
    assert_equal "task_test/subclass/eleven", subclass.default_name
  end
  
  #
  # Task.define test
  #
  
  class Define < Tap::Task
    BLOCK = lambda {}
    
    define :tap_task
    define :task_with_block, &BLOCK
    define :file_task, Tap::FileTask
  end
  
  # getter
  
  def test_define_task_makes_task_initializer
    t = Define.new
    assert t.respond_to?(:tap_task)
    assert_equal Tap::Task, t.tap_task.class
  end
  
  def test_define_task_returns_the_same_named_task_across_multiple_calls
    t = Define.new
    t1 = t.tap_task
    assert_equal t1.object_id, t.tap_task.object_id
    
    t2 = t.tap_task('alt')
    assert_equal t2.object_id, t.tap_task('alt').object_id
  end
  
  def test_define_task_sets_task_in_instance_variable_by_name
    t = Define.new
    t1 = t.tap_task
    t2 = t.tap_task('alt')
    assert_equal({:tap_task => t1, 'alt' => t2}, t.instance_variable_get(:@tap_task))
  end

  def test_defined_tasks_are_named_with_input_or_method_name_by_default
    t = Define.new
    assert_equal :tap_task, t.tap_task.name
    assert_equal 'alt', t.tap_task('alt').name
  end
  
  def test_defined_tasks_utilize_configurations_by_the_same_name
    t = Define.new(:tap_task => {:key => 'value'})
    assert_equal({:key => 'value'}, t.tap_task.config)
    
    t.config['alt'] = {:key => 'another'}
    assert_equal({:key => 'another'}, t.tap_task('alt').config)
  end
  
  def test_initialization_of_a_task_using_non_hash_or_nil_configs_raises_error
    t = Define.new :int => 2, :str => 'str', :hash => {}, :nil => nil
    
    assert_nothing_raised { t.tap_task(:hash) }
    assert_nothing_raised { t.tap_task(:nil) }
    assert_nothing_raised { t.tap_task(:non_existant) }
    assert_raise(ArgumentError) { t.tap_task(:int) }
    assert_raise(ArgumentError) { t.tap_task(:str) }
  end
  
  def test_initialization_initializes_class_using_block
    t = Define.new
    
    t1 = t.tap_task
    assert_equal Tap::Task, t1.class
    assert_equal nil, t1.task_block
    
    t2 = t.task_with_block
    assert_equal Tap::Task, t2.class
    assert_equal Define::BLOCK, t2.task_block
    
    t3 = t.file_task
    assert_equal Tap::FileTask, t3.class
    assert_equal nil, t3.task_block
  end
  
  def test_initialization_of_different_declarations_using_the_same_name_does_not_raise_an_error
    t = Define.new
    t.tap_task(:name)
    
    assert_nothing_raised { t.tap_task(:name) }
    assert_nothing_raised { t.task_with_block(:name) }
    assert_nothing_raised { t.file_task(:name) }
  end
  
  def test_configurations_for_defined_task_may_not_be_set_through_config
    t = Define.new
    t.config[:tap_task] = {:key => 'value'}
    t1 = t.tap_task
    
    assert_equal({:key => 'value'}, t1.config)
    t.config[:tap_task][:key] = 'VALUE'
    assert_equal({:key => 'value'}, t1.config)
  end
  
  # setter
  
  def test_define_task_makes_task_setter
    t = Define.new
    assert t.respond_to?(:tap_task=)
  end
  
  def test_define_task_setter_sets_instance_variable_if_hash
    t = Define.new
    t.tap_task = {:key => 'value'}
    assert_equal({:key => 'value'}, t.instance_variable_get(:@tap_task))
  end
  
  def test_define_task_setter_sets_input_by_name_in_instane_variable_if_input_is_not_a_hash
    t = Define.new
    t.tap_task = 'value'
    assert_equal({:tap_task => 'value'}, t.instance_variable_get(:@tap_task))
    assert_equal 'value', t.tap_task
  end
  
  #
  # initialization tests
  #
  
  def test_default_initialization
    assert_equal App.instance, t.app
    assert_equal({}, t.config)
    assert_equal [t], t.batch
    assert_nil t.task_block
    assert_equal "tap/task", t.name
  end
  
  def test_initialization_with_inputs
    app = App.new
    block = lambda {}
    
    t = Task.new({:key => 'value'}, "name", app, &block) 
    assert_equal "name", t.name
    assert_equal({:key => 'value'}, t.config)
    assert_equal app, t.app
    assert_equal block, t.task_block
  end

  def test_task_init_speed
    benchmark_test(20) do |x|
      x.report("10k") { 10000.times { Task.new } }
      x.report("10k {}") { 10000.times { Task.new {} } }
      x.report("10k ({},name) {}") { 10000.times { Task.new({},'name') {} } }
    end
  end

  def test_app_is_initialized_to_App_instance_by_default
    assert_equal Tap::App.instance, Task.new.app
  end

  def test_by_default_tasks_share_application_instance
    t1 = Task.new
    t2 = Task.new
    
    assert_equal t1.app, t2.app
    assert_equal App.instance, t1.app
  end

  def test_instance_configs_are_bound_to_self
    ic = Sample.configurations.instance_config
    assert !ic.bound?
    
    s = Sample.new(ic)
    assert ic.bound?
    assert_equal s, ic.receiver
    assert_equal ic, s.config
  end
  
  def test_name_is_set_to_class_default_name_unless_specified
    t = Task.new
    assert_equal Task.default_name, t.name
    
    t = Task.new({}, 'alt')
    assert_equal "alt", t.name
    
    s = Sample.new
    assert_equal Sample.default_name, s.name
  end
  
  #
  # initialize_batch_obj test
  #

  def test_initialize_batch_obj_renames_batch_object_if_specified
    t = Task.new
    t1 = t.initialize_batch_obj({}, 'new_name')
    assert_equal "new_name", t1.name
  end

  def test_initialize_batch_obj_reconfigures_batch_obj_with_overrides
    s = Sample.new :three => 3
    assert_equal({:one => 'one', :two => 'two', :three => 3}, s.config)

    s1 = s.initialize_batch_obj
    assert_equal({:one => 'one', :two => 'two', :three => 3}, s1.config)  

    s2 = s.initialize_batch_obj(:one => 'ONE')
    assert_equal({:one => 'ONE', :two => 'two', :three => 3}, s2.config)
  end

  #
  # enq test
  #
  
  def test_enq_enqueues_task_to_app_queue_with_inputs
    assert t.app.queue.empty?
    
    t.enq 1
    
    assert_equal 1, t.app.queue.size
    assert_equal [[t, [1]]], t.app.queue.to_a
    
    t.enq 1
    t.enq 2
    
    assert_equal [[t, [1]], [t, [1]], [t, [2]]], t.app.queue.to_a
  end

  def test_enq_enqueues_task_batch
    t2 = t.initialize_batch_obj
    
    assert t.app.queue.empty?
    assert_equal 2, t.batch.size
    
    t.enq 1
    
    assert_equal 2, t.app.queue.size
    assert_equal [[t, [1]], [t2, [1]]], t.app.queue.to_a
  end
  
  def test_unbatched_enq_only_enqueues_task
    t2 = t.initialize_batch_obj
    
    assert_equal 2, t.batch.size
    assert t.app.queue.empty?
    t.unbatched_enq 1
    
    assert_equal 1, t.app.queue.size
    assert_equal [[t, [1]]], t.app.queue.to_a
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_completes_task_batch
    t2 = t.initialize_batch_obj
    
    assert_nil t.on_complete_block
    assert_nil t2.on_complete_block

    b = lambda {}
    t.on_complete(&b)
    
    assert_equal b, t.on_complete_block
    assert_equal b, t2.on_complete_block
  end
  
  def test_unbatched_on_complete_only_completes_task
    t2 = t.initialize_batch_obj
    
    assert_nil t.on_complete_block
    assert_nil t2.on_complete_block

    b = lambda {}
    t.unbatched_on_complete(&b)
    
    assert_equal b, t.on_complete_block
    assert_nil t2.on_complete_block
  end
  
  #
  # process test
  #
  
  class TaskWithTwoInputsForProcessDoc < Tap::Task
    def process(a, b)
      [b,a]
    end
  end
  
  def test_process_documentation
    t = TaskWithTwoInputsForProcessDoc.new
    t.enq(1,2).enq(3,4)
    t.app.run
    assert_equal [[2,1], [4,3]], t.app.results(t)

    t = Task.new {|task, a, b| [b,a] }
    t.enq(1,2).enq(3,4)
    t.app.run
    assert_equal [[2,1], [4,3]], t.app.results(t)
  end
  
  def test_process_calls_task_block_with_input
    b = lambda do |task, input|
      runlist << input
      input += 1
    end
    t = Task.new(&b)
  
    assert_equal b, t.task_block
    assert_equal 2, t.process(1)
    assert_equal [1], runlist
  end
  
  def test_process_returns_inputs_if_task_block_is_not_set
    t = Task.new
    assert_nil t.task_block
    assert_equal [1,2,3], t.process(1,2,3)
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_name
    t = Task.new
    assert_equal t.name, t.to_s
    
    t.name = "alt_name"
    assert_equal "alt_name", t.to_s
  end
  
  def test_to_s_stringifies_name
    t = Task.new({}, :name)
    assert_equal :name, t.name
    assert_equal 'name', t.to_s
  end
  
  #
  # dependency resolution test
  #
  
  class DependencyResolutionClass < Tap::Task
    attr_reader :resolution_arguments
    
    def initialize
      super()
      @resolution_arguments = []
    end
    
    def process(*inputs)
      @resolution_arguments << inputs
    end
  end
  
  class DependentResolutionClass < Tap::Task
    depends_on DependencyResolutionClass
    depends_on DependencyResolutionClass, 1,2,3
  end
  
  def test_dependencies_are_resolved_only_once_per_argument_set
    d = DependentResolutionClass.new
    dependency = DependencyResolutionClass.instance
    
    assert_equal [], dependency.resolution_arguments
    d._execute 
    assert_equal [[], [1,2,3]], dependency.resolution_arguments
    
    d._execute 
    assert_equal [[], [1,2,3]], dependency.resolution_arguments
  end

end