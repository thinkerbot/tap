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
    app.root = ctr.root
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
    t1 = Tap::Task.subclass(:key => 'one') do |input| 
      input + config[:key]
    end.new
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
  # Task.define test
  #
  
  class AddALetter < Tap::Task
    config :letter, 'a'
    def process(input); input << letter; end
  end

  class AlphabetSoup < Tap::Task
    define :a, AddALetter, {:letter => 'a'}
    define :b, AddALetter, {:letter => 'b'}
    define :c, AddALetter, {:letter => 'c'}

    def workflow
      a.sequence(b, c)
    end

    def process
      a.execute("")
    end
  end
  
  def test_define_documentation
    assert_equal 'abc', AlphabetSoup.new.process

    i = AlphabetSoup.new(:a => {:letter => 'x'}, :b => {:letter => 'y'}, :c => {:letter => 'z'})
    assert_equal 'xyz', i.process

    i.config[:a] = {:letter => 'p'}
    i.config[:b][:letter] = 'q'
    i.c.letter = 'r'
    assert_equal 'pqr', i.process
  end
  
  class Define < Tap::Task
    define :define_task, Tap::Task, {:key => 'value'} do
      "result"
    end
    
    config :key, 'define value'
    
    def process
      'define result'
    end
  end
  
  def test_define_subclasses_task_class_with_name_configs_and_block
    assert Define.const_defined?(:DefineTask)
    assert_equal Tap::Task, Define::DefineTask.superclass
    
    define_task = Define::DefineTask.new
    assert_equal 'define_task', define_task.name
    assert_equal({:key => 'value'}, define_task.config.to_hash)
    assert_equal "result", define_task.process
  end
  
  def test_define_creates_reader_initialized_to_subclass
    t = Define.new
    assert t.respond_to?(:define_task)
    assert_equal Define::DefineTask,  t.define_task.class
    
    assert_equal 'define_task', t.define_task.name
    assert_equal({:key => 'value'}, t.define_task.config.to_hash)
    assert_equal "result", t.define_task.process
  end
  
  def test_define_creates_instance_config_reader_for_task
    t = Define.new
    assert t.respond_to?(:define_task_config)
    assert_equal t.define_task.config, t.define_task_config
  end
  
  def test_define_creates_instance_config_writer_for_task
    t = Define.new
    assert t.respond_to?(:define_task_config=)
    assert_equal({:key => 'value'}, t.define_task.config.to_hash)
    
    t.define_task_config = {:key => 'one'}
    assert_equal({:key => 'one'}, t.define_task.config.to_hash)
  end
  
  def test_define_adds_config_by_name_to_configurations
    assert Define.configurations.key?(:define_task)
    config = Define.configurations[:define_task]
    
    assert_equal :define_task_config, config.reader
    assert_equal :define_task_config=, config.writer
    assert_equal Tap::Support::InstanceConfiguration, config.default.class
    assert_equal Define::DefineTask.configurations, config.default.class_config
  end
  
  def test_instance_is_initialized_with_configs_by_the_same_name
    t = Define.new :define_task => {:key => 'one'}
    assert_equal({:key => 'one'}, t.define_task.config.to_hash)
  end
  
  def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
    t = Define.new
    assert_equal({:key => 'value'}, t.define_task.config.to_hash)
    
    t.config[:define_task][:key] = 'zero'
    assert_equal({:key => 'zero'}, t.define_task.config.to_hash)
    
    t.config[:define_task]['key'] = 'one'
    assert_equal({:key => 'one'}, t.define_task.config.to_hash)
    
    t.config[:define_task] = {:key => 'two'}
    assert_equal({:key => 'two'}, t.define_task.config.to_hash)
    
    t.config[:define_task] = {'key' => 'three'}
    assert_equal({:key => 'three'}, t.define_task.config.to_hash)
    
    t.define_task.key = "two"
    assert_equal({:key => 'two'}, t.config[:define_task])
    
    t.define_task.reconfigure(:key => 'one')
    assert_equal({:key => 'one'}, t.config[:define_task])
    
    t.define_task.config[:key] = 'zero'
    assert_equal({:key => 'zero'}, t.config[:define_task])
  end
  
  class NestedDefine < Tap::Task
    define :nested_define_task, Define
    
    config :key, 'nested define value'
    
    def process
      'nested define result'
    end
  end
  
  def test_nested_defined_tasks_initialize_properly
    t = NestedDefine.new
    
    assert_equal NestedDefine::NestedDefineTask, t.nested_define_task.class
    assert_equal Define, t.nested_define_task.class.superclass
    
    assert_equal Define::DefineTask, t.nested_define_task.define_task.class
    assert_equal Tap::Task, t.nested_define_task.define_task.class.superclass
    
    assert_equal({
      :key => 'nested define value', 
      :nested_define_task => t.nested_define_task.config
    }, t.config.to_hash)
    
    assert_equal({
      :key => 'define value', 
      :define_task => t.nested_define_task.define_task.config
    }, t.nested_define_task.config.to_hash)
    
    assert_equal({
      :key => 'value'
    }, t.nested_define_task.define_task.config.to_hash)
    
    assert_equal 'nested define result', t.process
    assert_equal 'define result', t.nested_define_task.process
    assert_equal 'result', t.nested_define_task.define_task.process
  end
  
  def test_nested_defined_tasks_allow_nested_configuration
    t = NestedDefine.new :key => 'zero', :nested_define_task => {:key => 'one', :define_task => {:key => 'two'}}
    
    assert_equal({
      :key => 'zero', 
      :nested_define_task => t.nested_define_task.config
    }, t.config.to_hash)
    
    assert_equal({
      :key => 'one', 
      :define_task => t.nested_define_task.define_task.config
    }, t.nested_define_task.config.to_hash)
    
    assert_equal({
      :key => 'two'
    }, t.nested_define_task.define_task.config.to_hash)
    
    t.config[:nested_define_task][:define_task][:key] = 'three'
    assert_equal({:key => 'three'}, t.nested_define_task.define_task.config.to_hash)
    
    t.config[:nested_define_task] = {:define_task => {:key => 'four'}}
    assert_equal({:key => 'four'}, t.nested_define_task.define_task.config.to_hash)
  end
  
  #
  # initialization tests
  #
  
  def test_default_initialization
    assert_equal App.instance, t.app
    assert_equal({}, t.config)
    assert_equal [t], t.batch
    assert_equal "tap/task", t.name
  end
  
  def test_initialization_with_inputs
    app = App.new
    block = lambda {}
    
    t = Task.new({:key => 'value'}, "name", app) 
    assert_equal "name", t.name
    assert_equal({:key => 'value'}, t.config)
    assert_equal app, t.app
  end

  def test_task_init_speed
    benchmark_test(20) do |x|
      x.report("10k") { 10000.times { Task.new } }
      x.report("10k {}") { 10000.times { Task.new {} } }
      x.report("10k ({},name) {}") { 10000.times { Task.new({},'name') {} } }
    end
  end
  
  def test_task_subclass_speed
    benchmark_test(20) do |x|
      x.report("1k") { 1000.times { Task.subclass } }
      x.report("1k n,c") { 1000.times { Task.subclass({:key => 'value'}, name) } }
      x.report("1k block") { 1000.times { Task.subclass() {} } }
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
  end
  
  def test_process_returns_inputs
    t = Task.new
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