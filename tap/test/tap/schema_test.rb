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
    schema = Schema.new 'tasks' => [:a, :b, :c]
    assert_equal({0 => :a, 1 => :b, 2 => :c}, schema.tasks)
  end
  
  def test_initialize_arrayifies_joins_hash
    schema = Schema.new 'joins' => {
      0 => [[2],[3]],
      1 => [[4],[5]]
    }
    assert_equal [
      [[2],[3], nil], 
      [[4],[5], nil]
    ], schema.joins
  end
  
  def test_initialize_arrayifies_individual_joins
    schema = Schema.new 'joins' => {
      0 => {
        0 => [2],
        1 => [3],
        2 => ['join']
      },
      1 => {
        '0' => [4],
        '1' => [5],
        '2' => {'class' => 'join'}
      }
    }
    assert_equal [
      [[2],[3], ['join']], 
      [[4],[5], {'class' => 'join'}]
    ], schema.joins
  end
  
  #
  # resolve! test
  #
  
  def test_resolve_does_not_symbolize_tasks_keys
    schema.tasks['key'] = {'class' => Instantiable}
    schema.resolve!
    assert_equal({'key' => {'class' => Instantiable}}, schema.tasks)
  end
  
  def test_resolve_symbolizes_hash_tasks
    schema.tasks[:key] = {'class' => Instantiable}
    schema.resolve!
    assert_equal({:key => {'class' => Instantiable}}, schema.tasks)
  end
  
  def test_resolve_symbolizes_hash_joins
    schema.joins << [[], [], {'class' => Instantiable}]
    schema.resolve!
    assert_equal({'class' => Instantiable}, schema.joins[0][2])
  end
  
  def test_resolve_replaces_missing_class_with_block_return
    schema.tasks[0] = ['task array id']
    schema.tasks[1] = {'id' => 'task hash id'}
    
    schema.joins << [[], [], ['join array id']]
    schema.joins << [[], [], {'id' => 'join hash id'}]
    
    schema.resolve! do |type, id, data|
      Instantiable
    end
    
    assert_equal({
      0 => [Instantiable],
      1 => {'class' => Instantiable, 'id' => 'task hash id'}
    }, schema.tasks)
    
    assert_equal([
      [[], [], [Instantiable]],
      [[], [], {'class' => Instantiable, 'id' => 'join hash id'}]
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
    
    assert_equal({'class' => Instantiable}, schema.tasks['key'])
    
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
    
    assert_equal({'class' => Instantiable}, schema.tasks['key'])
  end
  
  def test_resolve_provides_default_join_id_if_unspecified
    schema.joins << [[], []]
    schema.resolve! do |type, id, data|
      assert_equal 'join', id
      Instantiable
    end
    
    assert_equal [[], [], {'class' => Instantiable}], schema.joins[0]
  end
end