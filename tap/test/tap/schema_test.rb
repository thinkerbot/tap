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
end