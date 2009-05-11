require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/schema'

class SchemaTest < Test::Unit::TestCase
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
  # initialize test
  #
  
  def test_initialize_hashifies_tasks_array
    schema = Schema.new :tasks => [:a, :b, :c]
    assert_equal({0 => :a, 1 => :b, 2 => :c}, schema.tasks)
  end
  
  #
  # empty? test
  #
  
  def test_empty_schema_have_all_parts_empty
    assert schema.empty?
    
    schema.tasks[0] = {}
    assert !schema.empty?
    schema.clear
    
    schema.joins << :join
    assert !schema.empty?
    schema.clear
    
    schema.queue << :queue
    assert !schema.empty?
    schema.clear
    
    schema.middleware << :m
    assert !schema.empty?
    schema.clear
    
    assert schema.empty?
  end
  
  #
  # resolved? test
  #
  
  def test_empty_schema_are_resolved
    assert schema.resolved?
  end
  
  def test_resolved_is_true_if_all_task_hashes_have_class
    schema.tasks[0] = {:class => Instantiable}
    schema.tasks[1] = {:class => Instantiable}
    
    assert schema.resolved?
    
    schema.tasks[0][:class] = :object
    assert !schema.resolved?
  end
  
  def test_resolved_is_true_if_all_task_arrays_have_first_classes
    schema.tasks[0] = [Instantiable]
    schema.tasks[1] = [Instantiable]
    
    assert schema.resolved?
    
    schema.tasks[0][0] = :object
    assert !schema.resolved?
  end
  
  def test_resolved_is_true_if_all_join_hashes_have_class
    schema.joins << [[], [], {:class => Instantiable}]
    schema.joins << [[], [], {:class => Instantiable}]
    
    assert schema.resolved?
    
    schema.joins[0][2][:class] = :object
    assert !schema.resolved?
  end
  
  def test_resolved_is_true_if_all_join_arrays_have_first_classes
    schema.joins << [[], [], [Instantiable]]
    schema.joins << [[], [], [Instantiable]]
    
    assert schema.resolved?
    
    schema.joins[0][2][0] = :object
    assert !schema.resolved?
  end
  
  #
  # resolve! test
  #
  
  def test_resolve_does_not_symbolize_tasks_keys
    schema.tasks['key'] = {:class => Instantiable}
    schema.resolve!
    assert_equal({'key' => {:class => Instantiable}}, schema.tasks)
  end
  
  def test_resolve_symbolizes_hash_tasks
    schema.tasks[:key] = {'class' => Instantiable}
    schema.resolve!
    assert_equal({:key => {:class => Instantiable}}, schema.tasks)
  end
  
  def test_resolve_symbolizes_hash_joins
    schema.joins << [[], [], {'class' => Instantiable}]
    schema.resolve!
    assert_equal({:class => Instantiable}, schema.joins[0][2])
  end
  
  def test_resolve_replaces_missing_class_with_block_return
    schema.tasks[0] = ['task array id']
    schema.tasks[1] = {:id => 'task hash id'}
    
    schema.joins << [[], [], ['join array id']]
    schema.joins << [[], [], {:id => 'join hash id'}]
    
    schema.resolve! do |type, id, data|
      Instantiable
    end
    
    assert_equal({
      0 => [Instantiable],
      1 => {:class => Instantiable, :id => 'task hash id'}
    }, schema.tasks)
    
    assert_equal([
      [[], [], [Instantiable]],
      [[], [], {:class => Instantiable, :id => 'join hash id'}]
    ], schema.joins)
  end
  
  def test_resolve_allows_modification_of_data
    schema.tasks[0] = ['task array id']
    schema.joins << [[], [], ['join array id']]

    schema.resolve! do |type, id, data|
      data << :value
      Instantiable
    end
    
    assert_equal [Instantiable, :value], schema.tasks[0]
    assert_equal [[], [], [Instantiable, :value]], schema.joins[0]
  end
  
  def test_resolve_provides_key_as_task_id_if_unspecified
    schema.tasks['key'] = {}
    schema.resolve! do |type, id, data|
      assert_equal 'key', id
      Instantiable
    end
    
    assert_equal({:class => Instantiable}, schema.tasks['key'])
    
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
    
    assert_equal({:class => Instantiable}, schema.tasks['key'])
  end
  
  def test_resolve_provides_default_join_id_if_unspecified
    schema.joins << [[], []]
    schema.resolve! do |type, id, data|
      assert_equal 'join', id
      Instantiable
    end
    
    assert_equal [[], [], {:class => Instantiable}], schema.joins[0]
  end
end