require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/workflow'

class WorkflowTest < Test::Unit::TestCase
  
  #
  # Workflow.define test
  #
  
  class AddALetter < Tap::Task
    config :letter, 'a'
    def call(input); input << letter end
  end
  
  class AlphabetSoup < Tap::Workflow
    define :a, AddALetter, {:letter => 'a'}
    define :b, AddALetter, {:letter => 'b'}
    define :c, AddALetter, {:letter => 'c'}
    
    def process
      Tap::Join.new.join([a], [b])
      Tap::Join.new.join([b], [c])
      [a, c]
    end
  end
  
  def test_define_documentation
    assert_equal 'abc', AlphabetSoup.new.call('')
  
    i = AlphabetSoup.new(:a => {:letter => 'x'}, :b => {:letter => 'y'}, :c => {:letter => 'z'})
    assert_equal 'xyz', i.call('')
  
    i.config[:a] = {:letter => 'p'}
    i.config[:b][:letter] = 'q'
    i.c.letter = 'r'
    assert_equal 'pqr', i.call('')
  end
  
  class DefineClass < Tap::Workflow
    define :define_task, Tap::Task, {:key => 'value'} do
      "result"
    end
    
    config :key, 'define value'
  end
  
  def test_define_subclasses_baseclass_with_configs_and_block
    assert DefineClass.const_defined?(:DefineTask)
    assert_equal Tap::Task, DefineClass::DefineTask.superclass
    
    define_task = DefineClass::DefineTask.new
    assert_equal({:key => 'value'}, define_task.config.to_hash)
    assert_equal "result", define_task.process
  end
  
  def test_define_creates_reader_initialized_to_subclass
    t = DefineClass.new
    assert t.respond_to?(:define_task)
    assert_equal DefineClass::DefineTask,  t.define_task.class
    
    assert_equal({:key => 'value'}, t.define_task.config.to_hash)
    assert_equal "result", t.define_task.process
  end
  
  def test_define_adds_config_by_name_to_configurations
    assert DefineClass.configurations.key?(:define_task)
    config = DefineClass.configurations[:define_task]
    
    assert_equal :define_task, config.reader
    assert_equal :define_task=, config.writer
    assert_equal DefineClass::DefineTask, config.nest_class
  end
  
  def test_instance_is_initialized_with_configs_by_the_same_name
    t = DefineClass.new :define_task => {:key => 'one'}
    assert_equal({:key => 'one'}, t.define_task.config.to_hash)
  end
  
  def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
    t = DefineClass.new
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
    assert_equal({:key => 'two'}, t.config[:define_task].to_hash)
    
    t.define_task.reconfigure(:key => 'one')
    assert_equal({:key => 'one'}, t.config[:define_task].to_hash)
    
    t.define_task.config[:key] = 'zero'
    assert_equal({:key => 'zero'}, t.config[:define_task].to_hash)
  end
  
  class NestedDefineClass < Tap::Workflow
    define :nested_define_task, DefineClass
    
    config :key, 'nested define value'
  end
  
  def test_nested_defined_tasks_initialize_properly
    t = NestedDefineClass.new
    
    assert_equal NestedDefineClass::NestedDefineTask, t.nested_define_task.class
    assert_equal DefineClass, t.nested_define_task.class.superclass
    
    assert_equal DefineClass::DefineTask, t.nested_define_task.define_task.class
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
  end
  
  def test_nested_defined_tasks_allow_nested_configuration
    t = NestedDefineClass.new :key => 'zero', :nested_define_task => {:key => 'one', :define_task => {:key => 'two'}}
    
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
end