require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'

# used in documentation test
class NoInput < Tap::Task
  def process(); []; end
end

class OneInput < Tap::Task
  def process(input); [input]; end
end

class MixedInputs < Tap::Task
  def process(a, b, *args); [a,b,args]; end
end

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
    assert_equal [], NoInput.new.execute
    assert_equal [:a], OneInput.new.execute(:a)
    assert_equal [:a, :b, []], MixedInputs.new.execute(:a, :b)
    assert_equal [:a, :b, [1,2,3]], MixedInputs.new.execute(:a, :b, 1, 2, 3)
  
    no_inputs = Task.intern {|task| [] }
    one_input = Task.intern {|task, input| [input] }
    mixed_inputs = Task.intern {|task, a, b, *args| [a, b, args] }
  
    assert_equal [], no_inputs.execute
    assert_equal [:a], one_input.execute(:a)
    assert_equal [:a, :b, []], mixed_inputs.execute(:a, :b)
    assert_equal [:a, :b, [1,2,3]], mixed_inputs.execute(:a, :b, 1, 2, 3)
  
    ####
    t = ConfiguredTask.new
    assert_equal({:one => 'one', :two => 'two'}, t.config)
    assert_equal('one', t.one)
    t.one = 'ONE'
    assert_equal({:one => 'ONE', :two => 'two'}, t.config)
  
    t = ConfiguredTask.new(:one => 'ONE', :three => 'three')
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, t.config)
    assert_equal false, t.respond_to?(:three)
  
    ####
    t = ValidatingTask.new
    assert_raise(Configurable::Validation::ValidationError) { t.string = 1 }
    assert_raise(Configurable::Validation::ValidationError) { t.integer = 1.1 }

    t.integer = "1"
    assert t.integer == 1
  end
  
  def test_hidden_documentation
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
  # Task.load test
  #
  
  def prepare(path, obj=nil)
    path = method_root.filepath(:output, path)
    dirname = File.dirname(path)
    FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
    File.open(path, 'w') {|file| file << obj.to_yaml } if obj
    path
  end
  
  def test_load_returns_empty_array_for_non_existant_file
    path = method_root.filepath("non_existant.yml")
    assert !File.exists?(path)
    assert_equal({}, Task.load(path))
  end
  
  def test_load_returns_empty_array_for_empty_file
    path = method_tempfile("non_existant.yml") {}
    
    assert File.exists?(path)
    assert_equal "", File.read(path)
    assert_equal({}, Task.load(path))
  end
  
  def test_load_loads_existing_files_as_yaml
    path = method_tempfile("file.yml") {|file| file << {'key' => 'value'}.to_yaml }
    assert_equal({'key' => 'value'}, Task.load(path))
    
    path = method_tempfile("file.yml") {|file| file << [1,2].to_yaml }
    assert_equal([1,2], Task.load(path))
  end
  
  def test_load_recursively_loads_files
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", 'b value')
           prepare("a/c.yml", 'c value')
    
    a = {'key' => 'a value', 'b' => 'b value', 'c' => 'c value'}
    assert_equal(a, Task.load(path))
  end
  
  def test_load_recursively_loads_directories
    path = prepare("a.yml", {'key' => 'value'})
           prepare("a/b/c.yml", 'c value')
           prepare("a/c/d.yml", 'd value')
           
    a = {
       'key' => 'value',
       'b' => {'c' => 'c value'},
       'c' => {'d' => 'd value'}
    }
    assert_equal(a, Task.load(path))
  end
  
  def test_recursive_loading_with_files_and_directories
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", {'key' => 'b value'})
           prepare("a/b/c.yml", 'c value')
           
           prepare("a/d.yml", {'key' => 'd value'})
           prepare("a/d/e/f.yml", 'f value')
    
    d = {'key' => 'd value', 'e' => {'f' => 'f value'}}
    b = {'key' => 'b value', 'c' => 'c value'}
    a = {'key' => 'a value', 'b' => b, 'd' => d}
    
    assert_equal(a, Task.load(path))
  end
  
  def test_recursive_loading_sets_value_for_each_hash_in_a_parent_array
    path = prepare("a.yml", [{'key' => 'one'}, {'key' => 'two'}])
           prepare("a/b.yml", 'b value')
           
    a = [
      {'key' => 'one', 'b' => 'b value'},
      {'key' => 'two', 'b' => 'b value'}]
            
    assert_equal(a, Task.load(path))
  end
  
  def test_recursive_loading_with_files_and_directories_and_arrays
    path = prepare("a.yml", [{'key' => 'a one'}, {'key' => 'a two'}])
           prepare("a/b.yml", [{'key' => 'b one'}, {'key' => 'b two'}])
           prepare("a/b/c.yml", 'c value')
           
           prepare("a/d.yml", [{'key' => 'd one'}, {'key' => 'd two'}])
           prepare("a/d/e/f.yml", 'f value')
    
    d = [
      {'key' => 'd one', 'e' => {'f' => 'f value'}},
      {'key' => 'd two', 'e' => {'f' => 'f value'}}]
    b = [
      {'key' => 'b one', 'c' => 'c value'},
      {'key' => 'b two', 'c' => 'c value'}]
    a = [
      {'key' => 'a one', 'b' => b, 'd' => d},
      {'key' => 'a two', 'b' => b, 'd' => d}]
    
    assert_equal(a, Task.load(path))
  end
  
  def test_recursive_loading_does_not_override_values_set_in_parent
    path = prepare("a.yml", {'a' => 'set value', 'b' => 'set value'})
           prepare("a/b.yml", 'recursive value')
           prepare("a/c.yml", 'recursive value')
           
    a = {
      'a' => 'set value',
      'b' => 'set value',
      'c' => 'recursive value'
    }
    
    assert_equal(a, Task.load(path))
  end
  
  def test_load_does_not_recursively_load_over_single_values
    path = prepare("a.yml", 'single value')
           prepare("a/b.yml", 'b value')
    
    assert_equal('single value', Task.load(path))
  end
  
  def test_load_does_not_recusively_load_unless_specified
    path = prepare("a.yml", {'key' => 'a value'})
           prepare("a/b.yml", {'key' => 'ab value'})
           
    a = {'key' => 'a value'}
            
    assert_equal(a, Task.load(path, false))
  end
  
  def test_recursive_loading_raises_error_when_two_files_map_to_the_same_value
    path = prepare("a.yml", {})
    one = prepare("a/b.yml", 'one')
    two = prepare("a/b.yaml", 'two')
           
    e = assert_raise(RuntimeError) { Task.load(path) }
    assert_equal "multiple files load the same key: [\"b.yaml\", \"b.yml\"]", e.message
  end
  
  #
  # Task.use test
  #
  
  def test_use_returns_argv
    argv = []
    assert_equal argv.object_id, Task.use("path.yml", argv).object_id
  end
  
  def test_use_loads_path_as_YAML_and_concatenates_array_results_to_argv
    path = prepare("path.yml", [1,2,3])
    assert_equal [0,1,2,3], Task.use(path, [0])
  end
  
  def test_use_loads_path_as_YAML_and_pushes_non_hash_non_array_values_onto_argv
    path = prepare("path.yml", "string")
    assert_equal [0,"string"], Task.use(path, [0])
    
    path = prepare("path.yml", {:key => 'value'})
    assert_equal [0,{:key => 'value'}], Task.use(path, [0])
  end
  
  def test_use_does_nothing_if_path_does_not_exist
    assert !File.exists?("path.yml")
    assert_equal [], Task.use("path.yml", [])
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
  
  class DependencyClassOne < Tap::Task
    def process; 1; end
  end
  
  class DependencyClassTwo < Tap::Task
    def process; 2; end
  end
  
  class DependentClass < Tap::Task
    depends_on :one, DependencyClassOne
    depends_on :two, DependencyClassTwo
  end
  
  def test_depends_on_adds_dependency_class_to_dependencies
    assert_equal [DependencyClassOne, DependencyClassTwo], DependentClass.dependencies
  end
  
  def test_depends_on_returns_self
    assert_equal DependentClass, DependentClass.send(:depends_on, :one, DependencyClassOne)
  end
  
  class DependentDupClass < Tap::Task
    depends_on :one, DependencyClassOne
    depends_on :one, DependencyClassOne
  end
  
  def test_depends_on_does_not_add_duplicates
    assert_equal [DependencyClassOne], DependentDupClass.dependencies
  end
  
  class DependentParentClass < Tap::Task
    depends_on :one, DependencyClassOne
  end
  
  class DependentSubClass < DependentParentClass
    depends_on :two, DependencyClassTwo
  end
  
  def test_dependencies_are_inherited_down_but_not_up
    assert_equal [DependencyClassOne], DependentParentClass.dependencies
    assert_equal [DependencyClassOne, DependencyClassTwo], DependentSubClass.dependencies
  end
  
  def test_depends_on_makes_a_reader_for_the_results_of_the_dependency
    d = DependentClass.new
    d.reset_dependencies
    
    assert d.respond_to?(:one)
    assert d.respond_to?(:two)
    
    d.resolve_dependencies
    
    assert_equal 1, d.one
    assert_equal 2, d.two
  end
  
  def test_depends_on_reader_resolves_dependencies_if_needed
    d = DependentClass.new
    d.reset_dependencies
    
    assert_equal [false, false], d.dependencies.collect {|dep| dep.resolved? }
    assert_equal 1, d.one
    assert_equal [true, false], d.dependencies.collect {|dep| dep.resolved? }
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
  
  def test_define_adds_config_by_name_to_configurations
    assert Define.configurations.key?(:define_task)
    config = Define.configurations[:define_task]
    
    assert_equal :define_task_config_reader, config.reader
    assert_equal :define_task_config_writer, config.writer
    assert_equal Configurable::DelegateHash, config.default.class
    assert_equal Define::DefineTask.configurations, config.default.delegates
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
  
  def test_app_is_initialized_to_App_instance_by_default
    assert_equal Tap::App.instance, Task.new.app
  end

  def test_by_default_tasks_share_application_instance
    t1 = Task.new
    t2 = Task.new
    
    assert_equal t1.app, t2.app
    assert_equal App.instance, t1.app
  end

  def test_initialize_binds_delegate_hashes_to_self
    dhash = Configurable::DelegateHash.new
    assert !dhash.bound?
    
    s = Sample.new(dhash)
    assert dhash.bound?
    assert_equal s, dhash.receiver
    assert_equal dhash, s.config
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
  
end