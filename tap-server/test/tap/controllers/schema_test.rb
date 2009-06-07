require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/schema'

class Tap::Controllers::SchemaTest < Test::Unit::TestCase
  Schema = Tap::Schema
  
  acts_as_tap_test
  cleanup_dirs << :schema
  
  attr_reader :env, :server, :request
  
  def setup
    super
    @env = Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @server = Tap::Server.new Tap::Controllers::Schema, 
      :env => env, 
      :app => app, 
      :data => Tap::Server::Data.new(method_root.root)
      
    @request = Rack::MockRequest.new(server)

    @timeout = Time.now + 3
    @timeout_error = false
  end
  
  def load_schema(id)
    Schema.load_file method_root.path(:schema, id.to_s)
  end
  
  #
  # add test
  #
  
  def test_add_redirects_to_show
    response = request.post("/0?_method=add")
    assert_equal 302, response.status
    assert_equal "/0", response.location
  end
  
  def test_add_adds_tasks_in_the_tasks_parameter
    assert_equal 302, request.post("/0?_method=add&tasks[]=tap%3Atask").status
    assert_equal({"0" => {"id" => "tap:task"}}, load_schema(0).tasks)
  end
  
  def test_add_increments_task_id_to_get_a_unique_key
    request.post("/0?_method=add&tasks[]=a")
    request.post("/0?_method=add&tasks[]=b")
    request.post("/0?_method=add&tasks[]=c")
    
    assert_equal({
      "0" => {"id" => "a"},
      "1" => {"id" => "b"},
      "2" => {"id" => "c"}
    }, load_schema(0).tasks)
  end
  
  def test_add_may_specify_multiple_tasks
    request.post("/0?_method=add&tasks[]=a&tasks[]=b")
    
    assert_equal({
      "0" => {"id" => "a"},
      "1" => {"id" => "b"}
    }, load_schema(0).tasks)
  end
  
  def test_add_adds_a_join_as_specified_by_inputs_and_outputs
    request.post("/0?_method=add&inputs[]=0&outputs[]=1")
    
    assert_equal [
      [["0"], ["1"], {'id' => 'join'}]
    ], load_schema(0).joins
    
    request.post("/1?_method=add&inputs[]=0&inputs[]=1&outputs[]=2&outputs[]=3")
    
    assert_equal [
      [["0", "1"], ["2", "3"], {'id' => 'join'}]
    ], load_schema(1).joins
  end
  
  def test_add_join_must_specifiy_at_least_one_input_and_output
    request.post("/0?_method=add&inputs[]=0")
    request.post("/0?_method=add&outputs[]=0")
    
    assert_equal [], load_schema(0).joins
  end
  
  def test_add_join_uses_join_id_if_specified
    request.post("/0?_method=add&inputs[]=0&outputs[]=1&join=sync")
    
    assert_equal [
      [["0"], ["1"], {'id' => 'sync'}]
    ], load_schema(0).joins
  end
  
  def test_add_adds_queues_in_the_queue_parameter
    request.post("/0?_method=add&queue[]=0&queue[]=1")
    assert_equal [
      ["0", []], 
      ["1", []]
    ], load_schema(0).queue
  end
  
  def test_add_adds_middleware_in_the_middleware_parameter
    request.post("/0?_method=add&middleware[]=a&middleware[]=b")
    assert_equal [
      {"id" => "a"}, 
      {"id" => "b"}
    ], load_schema(0).middleware
  end
  
  #
  # remove test
  #
  
  def test_remove_redirects_to_show
    response = request.post("/0?_method=remove")
    assert_equal 302, response.status
    assert_equal "/0", response.location
  end
  
  def test_remove_removes_tasks_in_the_tasks_parameter
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {'id' => 'load'},
          'b' => {'id' => 'dump'}
        }
      }.to_yaml
    end
    
    request.post("/0?_method=remove&tasks[]=a")
    assert_equal({"b" => {"id" => "dump"}}, load_schema(0).tasks)
  end
  
  def test_remove_removes_joins_in_the_joins_parameter
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {},
          'b' => {},
          'c' => {}
        },
        'joins' => [
          [['a'],['b']],
          [['b'],['c']],
          [['c'],['a']]
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove&joins[]=1")
    assert_equal([
      [['a'],['b']], 
      [['c'],['a']]
    ], load_schema(0).joins)
  end
  
  def test_remove_removes_queues_in_the_queue_parameter
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {},
          'b' => {},
          'c' => {}
        },
        'queue' => [
          ['a', []],
          ['b', []],
          ['c', []]
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove&queue[]=1")
    assert_equal([
      ['a', []],
      ['c', []]
    ], load_schema(0).queue)
  end
  
  def test_remove_removes_middleware_in_the_middleware_parameter
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'middleware' => [
          {'id' => 'a'},
          {'id' => 'b'},
          {'id' => 'c'}
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove&middleware[]=1")
    assert_equal([
      {'id' => 'a'},
      {'id' => 'c'}
    ], load_schema(0).middleware)
  end
  
  def test_remove_cleans_up_orphaned_joins
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {},
          'b' => {}
        },
        'joins' => [
          [['a'],['b']],
          [[],['b']],
          [['b'],[]],
          [['c'],['d']]
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove&joins[]=1")
    assert_equal([
      [['a'],['b']]
    ], load_schema(0).joins)
  end
  
  def test_remove_cleans_up_orphaned_queues
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {}
        },
        'queue' => [
          ['a', []],
          ['b', []]
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove")
    assert_equal([
      ['a', []]
    ], load_schema(0).queue)
  end
  
  def test_tasks_are_removed_before_cleanup
    method_root.prepare(:schema, 0.to_s) do |file|
      file << {
        'tasks' => {
          'a' => {},
          'b' => {},
          'c' => {}
        },
        'joins' => [
          [['a'],['b']],
          [['b'],['c']],
          [['c'],['a']]
        ],
        'queue' => [
          ['a', []],
          ['b', []],
          ['c', []]
        ]
      }.to_yaml
    end
    
    request.post("/0?_method=remove&tasks[]=b")
    
    schema = load_schema(0)
    assert_equal({
      'a' => {},
      'c' => {}
    }, schema.tasks)
    
    assert_equal([
      [['c'],['a']]
    ], schema.joins)
    
    assert_equal([
      ['a', []],
      ['c', []]
    ], schema.queue)
  end
end