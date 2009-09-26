require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/task'
require 'tap/test'

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

class TaskAppTest < Test::Unit::TestCase
  def test_task_documentation
    app = Tap::App.new
    
    no_inputs = app.task {|task| [] }
    one_input = app.task {|task, input| [input] }
    mixed_inputs = app.task {|task, a, b, *args| [a, b, args] }
  
    assert_equal [], no_inputs.execute
    assert_equal [:a], one_input.execute(:a)
    assert_equal [:a, :b, []], mixed_inputs.execute(:a, :b)
    assert_equal [:a, :b, [1,2,3]], mixed_inputs.execute(:a, :b, 1, 2, 3)
  end
end

class TaskTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Task = Tap::Task
  
  attr_accessor :t
  
  def setup
    super
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
  # Task.parse test
  #
  
  def test_parse_returns_instance
    instance, args = Task.parse([1,2,3])
    assert_equal Task, instance.class
  end
  
  class ParseClass < Tap::Task
    config :key, 'value'
  end
  
  def test_parse_returns_instance_of_subclass
    instance, args = ParseClass.parse([])
    assert_equal ParseClass, instance.class
  end
  
  def test_parse_instance_is_initialized_with_default_config
    instance, args = ParseClass.parse([])
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_parse_reconfigures_instance_using_configs_in_argv
    instance, args = ParseClass.parse(%w{--key alt})
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_adds_configs_from_file_using_config_option
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({:key => 'alt'})
    end
    
    instance, args = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_config_files_may_have_string_keys
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << YAML.dump({'key' => 'alt'})
    end
    
    instance, args = ParseClass.parse(["--config", path])
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_parse_raises_error_for_ambiguity_in_configs
    path = method_root.prepare(:tmp, 'config.yml') do |file| 
      file << {'key' => 'one'}.to_yaml
    end
    
    err = assert_raises(RuntimeError) { ParseClass.parse ["--key", "two", "--config", path] }
    assert_equal "multiple values map to config: :key", err.message
    
    err = assert_raises(RuntimeError) { ParseClass.parse ["--config", path, "--key", "two"] }
    assert_equal "multiple values map to config: :key", err.message
  end
  
  def test_parse_uses_ARGV_if_unspecified
    current_argv = ARGV.dup
    begin
      ARGV.clear
      ARGV.concat(%w{--key alt})
      
      instance, args = ParseClass.parse
      assert_equal({:key => 'alt'}, instance.config)
    ensure
      ARGV.clear
      ARGV.concat(current_argv)
    end
  end
  
  #
  # parse! test
  #
  
  def test_parse_bang_removes_args_from_input
    argv = [1, "--key", "alt", 2, 3]
    instance, args = ParseClass.parse!(argv)
    assert_equal({:key => 'alt'}, instance.config)
    assert_equal [1,2,3], argv
  end
  
  #
  # build test
  #
  
  class BuildClass < Tap::Task
    config :key, 'value'
  end
  
  def test_build_returns_instance_of_subclass
    instance, args = BuildClass.build
    assert_equal BuildClass, instance.class
  end
  
  def test_instance_is_built_with_default_config
    instance, args = BuildClass.build
    assert_equal({:key => 'value'}, instance.config)
  end
  
  def test_instance_is_built_with_user_config
    instance, args = BuildClass.build 'config' => {:key => 'alt'}
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  def test_build_respects_indifferent_access
    instance, args = BuildClass.build 'config' => {'key' => 'alt'}
    assert_equal({:key => 'alt'}, instance.config)
  end
  
  class NestedBuildClass < Tap::Task
    config :key, nil
  end
  
  class NestingBuildClass < Tap::Task
    config :key, nil
    define :nest, NestedBuildClass do |config|
      NestedBuildClass.new(config)
    end
  end
  
  def test_build_reconfigures_nested_tasks
    instance, args = NestingBuildClass.build 'config' => {
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
  # Task.define test
  #
  
  class AddALetter < Tap::Task
    config :letter, 'a'
    def process(input); input << letter end
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
  
  def test_define_subclasses_task_class_with_configs_and_block
    assert Define.const_defined?(:DefineTask)
    assert_equal Tap::Task, Define::DefineTask.superclass
    
    define_task = Define::DefineTask.new
    assert_equal({:key => 'value'}, define_task.config.to_hash)
    assert_equal "result", define_task.process
  end
  
  def test_define_creates_reader_initialized_to_subclass
    t = Define.new
    assert t.respond_to?(:define_task)
    assert_equal Define::DefineTask,  t.define_task.class
    
    assert_equal({:key => 'value'}, t.define_task.config.to_hash)
    assert_equal "result", t.define_task.process
  end
  
  def test_define_adds_config_by_name_to_configurations
    assert Define.configurations.key?(:define_task)
    config = Define.configurations[:define_task]
    
    assert_equal :define_task, config.reader
    assert_equal :define_task=, config.writer
    assert_equal Define::DefineTask, config.nest_class
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
  end
  
  def test_initialization_with_config
    t = Task.new({:key => 'value'})
    assert_equal({:key => 'value'}, t.config)
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
  
    t = TaskWithTwoInputs.new({}, app)
    t.enq(1,2).enq(3,4)
    
    app.run
    assert_equal [[2,1], [4,3]], results
  end
  
  def test_process_returns_inputs
    t = Task.new
    assert_equal [1,2,3], t.process(1,2,3)
  end

end