require File.join(File.dirname(__FILE__), '../tap_test_helper')
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
  include MethodRoot
  
  attr_accessor :t, :app
  
  def setup
    super
    Tap::App.instance = nil
    @app = Tap::App.instance
    @t = Task.new
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
    assert_raises(Configurable::Validation::ValidationError) { t.string = 1 }
    assert_raises(Configurable::Validation::ValidationError) { t.integer = 1.1 }
  
    t.integer = "1"
    assert t.integer == 1
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
  # Task.parse test
  #
  
  def test_parse_returns_instance_and_args
    instance, args = Task.parse([1,2,3])
    assert_equal 'tap/task', instance.name
    assert_equal [1,2,3], args
  end
  
  def test_parse_uses_ARGV_if_unspecified
    current_argv = ARGV.dup
    begin
      ARGV.clear
      ARGV.concat([1,2,3])
      
      instance, args = Task.parse
      assert_equal 'tap/task', instance.name
      assert_equal [1,2,3], args
    ensure
      ARGV.clear
      ARGV.concat(current_argv)
    end
  end
  
  class ParseClass < Tap::Task
    config :key, 'value'
  end
  
  def test_parse_returns_instance_of_subclass
    instance, argv = ParseClass.parse([])
    assert_equal ParseClass, instance.class
  end
  
  def test_parse_instance_is_initialized_with_default_name_and_config
    instance, argv = ParseClass.parse([])
    assert_equal(ParseClass.default_name, instance.name)
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_parse_reconfigures_instance_using_configs_in_argv
    instance, argv = ParseClass.parse(%w{--key alt})
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_sets_name_using_name_option
    instance, argv = ParseClass.parse(["--name", "alt"])
    assert_equal('alt', instance.name)
  end
  
  def test_parse_reconfigures_instance_using_config_option
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({:key => 'alt'})
    end
    
    instance, argv = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_config_files_may_have_string_keys
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({'key' => 'alt'})
    end
    
    instance, argv = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_configs_in_argv_override_config_file
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << {'key' => 'one'}.to_yaml
    end
    
    instance, argv = ParseClass.parse ["--key", "two", "--config", path]
    assert_equal({:key => 'two'}, instance.config)
    
    instance, argv = ParseClass.parse ["--config", path, "--key", "two"]
    assert_equal({:key => 'two'}, instance.config)
  end
  
  def test_parse_returns_remaining_args_in_argv
    instance, argv = ParseClass.parse(%w{1 --key value --name name 2 3})
    assert_equal %w{1 2 3}, argv
  end
  
  #
  # instantiate test
  #
  
  class InstantiateClass < Tap::Task
    config :key, 'value'
  end
  
  def test_instantiate_returns_instance_of_subclass
    instance, args = InstantiateClass.instantiate
    assert_equal InstantiateClass, instance.class
  end
  
  def test_instance_is_initialized_default_config
    instance, args = InstantiateClass.instantiate
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_instantiate_reconfigures_instance_using_config
    instance, args = InstantiateClass.instantiate :config => {:key => 'alt'}
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_instantiate_sets_name_using_name_option
    instance, args = InstantiateClass.instantiate :name => 'alt'
    assert_equal('alt', instance.name)
  end
  
  def test_instantiate_reconfigures_instance_using_config_file
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({:key => 'alt'})
    end
    
    instance, args = InstantiateClass.instantiate :config_file => path
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_config_files_may_have_string_keys
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({'key' => 'alt'})
    end
    
    instance, args = InstantiateClass.instantiate :config_file => path
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_configs_override_config_file
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({'key' => 'one'})
    end
    
    instance, args = InstantiateClass.instantiate :config_file => path, :config => {:key => 'two'}
    assert_equal({:key => 'two'}, instance.config)
    
    instance, args = InstantiateClass.instantiate :config_file => path, :config => {'key' => 'two'}
    assert_equal({:key => 'two'}, instance.config)
  end
  
  def test_instantiate_returns_args
    instance, args = InstantiateClass.instantiate :args => %w{1 2 3}
    assert_equal %w{1 2 3}, args
  end
  
  class NestedInstantiateClass < Tap::Task
    config :key, nil
  end
  
  class NestingInstantiateClass < Tap::Task
    config :key, nil
    define :nest, NestedInstantiateClass do |config|
      NestedInstantiateClass.new(config)
    end
  end
  
  def test_instantiate_reconfigures_nested_tasks
    instance, args = NestingInstantiateClass.instantiate :config => {
      'key' => 'one',
      'nest' => {'key' => 'two'}
    }
    
    assert_equal({:key => 'one', :nest => {:key => 'two'}}, instance.config.to_hash)
    assert_equal({:key => 'two'}, instance.nest.config)
  end
  
  #
  # Task.load_config test
  #
  
  def prepare_yaml(path, obj)
    method_root.prepare(:tmp, path) {|file| file << obj.to_yaml }
  end
  
  def test_load_config_returns_empty_array_for_non_existant_file
    path = method_root.path("non_existant.yml")
    assert !File.exists?(path)
    assert_equal({}, Task.load_config(path))
  end
  
  def test_load_config_returns_empty_array_for_empty_file
    path = method_root.prepare(:tmp, "non_existant.yml") {}
    
    assert File.exists?(path)
    assert_equal "", File.read(path)
    assert_equal({}, Task.load_config(path))
  end
  
  def test_load_config_loads_existing_files_as_yaml
    path = prepare_yaml("file.yml", {'key' => 'value'})
    assert_equal({'key' => 'value'}, Task.load_config(path))
    
    path = prepare_yaml("file.yml", [1,2])
    assert_equal([1,2], Task.load_config(path))
  end
  
  def test_load_config_recursively_loads_files
    path = prepare_yaml("a.yml", {'key' => 'a value'})
           prepare_yaml("a/b.yml", 'b value')
           prepare_yaml("a/c.yml", 'c value')
    
    a = {'key' => 'a value', 'b' => 'b value', 'c' => 'c value'}
    assert_equal(a, Task.load_config(path))
  end
  
  def test_load_config_recursively_loads_directories
    path = prepare_yaml("a.yml", {'key' => 'value'})
           prepare_yaml("a/b/c.yml", 'c value')
           prepare_yaml("a/c/d.yml", 'd value')
           
    a = {
       'key' => 'value',
       'b' => {'c' => 'c value'},
       'c' => {'d' => 'd value'}
    }
    assert_equal(a, Task.load_config(path))
  end
  
  def test_recursive_loading_with_files_and_directories
    path = prepare_yaml("a.yml", {'key' => 'a value'})
           prepare_yaml("a/b.yml", {'key' => 'b value'})
           prepare_yaml("a/b/c.yml", 'c value')
           
           prepare_yaml("a/d.yml", {'key' => 'd value'})
           prepare_yaml("a/d/e/f.yml", 'f value')
    
    d = {'key' => 'd value', 'e' => {'f' => 'f value'}}
    b = {'key' => 'b value', 'c' => 'c value'}
    a = {'key' => 'a value', 'b' => b, 'd' => d}
    
    assert_equal(a, Task.load_config(path))
  end
  
  def test_recursive_loading_does_not_override_values_set_in_parent
    path = prepare_yaml("a.yml", {'a' => 'set value', 'b' => 'set value'})
           prepare_yaml("a/b.yml", 'recursive value')
           prepare_yaml("a/c.yml", 'recursive value')
           
    a = {
      'a' => 'set value',
      'b' => 'set value',
      'c' => 'recursive value'
    }
    
    assert_equal(a, Task.load_config(path))
  end
  
  def test_load_config_does_not_recursively_load_over_single_values
    path = prepare_yaml("a.yml", 'single value')
           prepare_yaml("a/b.yml", 'b value')
    
    assert_equal('single value', Task.load_config(path))
  end
  
  def test_recursive_loading_raises_error_when_two_files_map_to_the_same_value
    path = prepare_yaml("a.yml", {})
    one = prepare_yaml("a/b.yml", 'one')
    two = prepare_yaml("a/b.yaml", 'two')
           
    e = assert_raises(RuntimeError) { Task.load_config(path) }
    assert_equal "multiple files load the same key: [\"b.yaml\", \"b.yml\"]", e.message
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
  
  class A < Tap::Task
    def process
      "result"
    end
  end
  
  class B < Tap::Task
    depends_on :a, A
  end
  
  def test_depends_on_documentation
    app = Tap::App.new
    b = B.new({}, :name, app)
    assert_equal [app.class_dependency(A)], b.dependencies
    assert_equal nil, b.a 
  
    app.resolve(b)
    assert_equal "result", b.a
  end
  
  class DependencyClassOne < Tap::Task
    def process; 1; end
  end
  
  class DependencyClassTwo < Tap::Task
    def process; 2; end
  end
  
  class DependentClass < Tap::Task
    depends_on :one, DependencyClassOne
    depends_on nil, DependencyClassTwo
  end
  
  def test_depends_on_adds_dependency_class_to_dependencies
    assert_equal [DependencyClassOne, DependencyClassTwo], DependentClass.dependencies
  end
  
  def test_depends_on_makes_a_reader_for_the_results_of_the_dependency
    d = DependentClass.new
    assert d.respond_to?(:one)
    
    assert_equal nil, d.one
    app.resolve(d)
    assert_equal 1, d.one
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
  
    def initialize(*args)
      super
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
    assert_equal Tap::App.instance, t.app
    assert_equal({}, t.config)
    assert_equal "tap/task", t.name
  end
  
  def test_initialization_with_inputs
    t = Task.new({:key => 'value'}, "name") 
    assert_equal "name", t.name
    assert_equal({:key => 'value'}, t.config)
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
  # process test
  #
  
  class TaskWithTwoInputs < Tap::Task
    def process(a, b)
      [b,a]
    end
  end
  
  def test_process_documentation
    results = []
    app = Tap::App.new {|result| results << result }
  
    t = TaskWithTwoInputs.new({}, :name, app)
    t.enq(1,2).enq(3,4)
    
    app.run
    assert_equal [[2,1], [4,3]], results
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