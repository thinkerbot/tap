require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controller/utils'

class ControllerUtilsTest < Test::Unit::TestCase
  include Tap::Controller::Utils
  
  #
  # yamlize test
  #
  
  def assert_yamlize(expected, obj)
    str = yamlize(obj)
    assert_equal expected, YAML.load(str), str
  end
  
  def test_yamlize
    assert_yamlize("str", "str")
    assert_yamlize(:sym, ":sym")
    assert_yamlize(nil, "~")
    
    assert_yamlize([1, 2, 3], ["1", "2", "3"])
    assert_yamlize({'key' => 'value'}, {'key' => 'value'})
    assert_yamlize({:a => 1, 2 => ["str", :sym, 3]}, {":a" => "1", "2" => ["str", ":sym", "3"]})
    
    resource = {
      'id' => 'task',
      'config' => {
        'key' => 'value',
        'list' => ['a', 'b', 'c'],
        'nest' => {
          'key' => 'value',
          'list' => ['a', 'b', 'c']
        }
      }
    }
    schema = {
      'tasks' => { 
        'key' => resource
      },
      'joins' => [
        [['a', 'b'], ['c', 'd'], resource]
      ],
      'queue' => [
        'a',
        ['a', ['x', 'y', 'z']]
      ]
    }
    assert_yamlize(schema, schema)
  end
end