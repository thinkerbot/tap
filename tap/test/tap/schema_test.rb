require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/schema'
require 'tap/task'

class SchemaTest < Test::Unit::TestCase
  include AppInstance
  
  Schema = Tap::Schema
  
  attr_reader :schema
  
  def setup
    super
    @schema = Schema.new
  end
  
  class Instantiable
    def self.parse!
    end
    def self.instantiate
    end
  end
  
  #
  # resolve! test
  #
  
  def test_resolve_replaces_missing_class_with_block_return_and_symbolizes
    schema.tasks[0] = ['task array id']
    schema.tasks[1] = {'id' => 'task hash id'}
    
    schema.joins << [[], [], ['join array id']]
    schema.joins << [[], [], {'id' => 'join hash id'}]
    
    schema.resolve! do |type, id, data|
      Instantiable
    end
    
    assert_equal({
      0 => [Instantiable],
      1 => {"class" => Instantiable, "id" => 'task hash id'}
    }, schema.tasks)
    
    assert_equal([
      [[], [], [Instantiable]],
      [[], [], {"class" => Instantiable, "id" => 'join hash id'}]
    ], schema.joins)
  end
  
  def test_resolve_provides_key_as_task_id_if_unspecified
    schema.tasks['key'] = {}
    schema.resolve! do |type, id, data|
      assert_equal 'key', id
      Instantiable
    end
    
    assert_equal({"class" => Instantiable}, schema.tasks['key'])
    
    # now for array
    schema.tasks['key'] = []
    schema.resolve! do |type, id, data|
      assert_equal 'key', id
      Instantiable
    end
    
    assert_equal([Instantiable], schema.tasks['key'])
    
    # now for nil
    schema.tasks['key'] = nil
    schema.resolve! do |type, id, data|
      assert_equal 'key', id
      Instantiable
    end
    
    assert_equal({"class" => Instantiable}, schema.tasks['key'])
  end
  
  def test_resolve_provides_default_join_id_if_unspecified
    schema.joins << [[], []]
    schema.resolve! do |type, id, data|
      assert_equal 'join', id
      Instantiable
    end
    
    assert_equal [[], [], {"class" => Instantiable}], schema.joins[0]
  end
  
  #
  # build test
  #
  
  def test_build_instantiates_tasks_to_app
    schema.tasks['key'] = {'class' => Tap::Task}
    schema.build!(app)
    
    task = schema.tasks['key']
    assert_equal Tap::Task, task.class
    assert_equal app, task.app
  end
  
  def test_build_validates_self
    schema.tasks['key'] = {}
    err = assert_raises(RuntimeError) { schema.build!(app) }
    assert_equal "unresolvable task: {}\n", err.message
  end
  
  def test_build_does_not_validate_self_unless_specified
    schema.tasks['key'] = {}
    err = assert_raises(NoMethodError) { schema.build!(app, false) }
    assert_equal "undefined method `instantiate' for nil:NilClass", err.message
  end
  
  def test_build_returns_self
    assert_equal schema, schema.build!(app)
  end
  
  #
  # built?
  #
  
  def test_built_is_true_after_build
    assert !schema.built?
    schema.build!(app)
    assert schema.built?
  end
  
  #
  # enque test
  #
  
  def test_enque_enques_task_to_app
    schema.tasks['key'] = {'class' => Tap::Task}
    schema.build!(app)
    
    assert app.queue.empty?
    
    task = schema.tasks['key']
    schema.enque('key', 1,2,3)
    assert_equal [[task, [1,2,3]]], app.queue.to_a
  end
  
  def test_enque_raises_error_unless_built
    err = assert_raises(RuntimeError) { schema.enque('key') }
    assert_equal "cannot enque unless built", err.message
  end
  
  def test_enque_raises_error_unless_key_maps_to_task
    schema.build!(app)
    err = assert_raises(RuntimeError) { schema.enque('key') }
    assert_equal "unknown task: \"key\"", err.message
  end
  
end