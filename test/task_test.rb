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
  
  def test_instance_returns_class_level_instance_extended_by_Dependency
    i = Task.instance
    assert_equal Task, i.class
    assert i.kind_of?(Support::Dependency)
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
    assert_raise(ArgumentError) { DependentClass.send(:depends_on, Object) }
    assert_raise(ArgumentError) { DependentClass.send(:depends_on, Object.new) }
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
  
  def test_dependencies_are_set_to_instances_of_class_dependencies_and_args
    assert_equal [], t.dependencies
    
    d = DependentClass.new
    assert_equal [
      [DependencyClass.instance, []],
      [DependencyClass.instance, [1,2,3]]
    ], d.dependencies
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
  # multithread= test
  #
  
  def test_set_multithread_sets_multithread_for_task_batch
    t2 = t.initialize_batch_obj
    
    assert !t.multithread
    assert !t2.multithread

    t.multithread = true
    
    assert t.multithread
    assert t2.multithread
  end
  
  def test_unbatched_set_multithread_sets_multithread_for_task_only
    t2 = t.initialize_batch_obj
    
    assert !t.multithread
    assert !t2.multithread

    t.unbatched_multithread = true
    
    assert t.multithread
    assert !t2.multithread
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