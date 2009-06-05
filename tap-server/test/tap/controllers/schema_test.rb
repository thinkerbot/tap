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
  
  def prepare_schema(id, str)
    method_root.prepare(:schema, id.to_s) do |file|
      file << Schema.parse(str).dump
    end
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
  
  def test_post_remove_removes_nodes_indicated_in_both_inputs_and_outputs
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/0?action=remove&inputs[]=1&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- c", schema.to_s
  end
  
  def test_remove_removes_join_outputs_for_inputs
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/0?action=remove&inputs[]=0", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --[1][2]", schema.to_s
  end
  
  def test_remove_removes_join_inputs_for_outputs
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/0?action=remove&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --[0][] --[1][2]", schema.to_s
  end
  
  def test_remove_removes_join_and_not_node_when_joins_exist
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/0?action=remove&inputs[]=1&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --[0][]", schema.to_s
  end
  
  def test_remove_removes_join_when_two_joined_nodes_are_both_selected
    path = prepare_schema(0, "a -- b --0:1")
    assert_equal 302, request.post("/0?action=remove&inputs[]=0&inputs[]=1&outputs[]=0&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b", schema.to_s
  end
  
  def test_remove_does_not_remove_nodes_unless_indicated_in_both_inputs_and_outputs
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/0?action=remove&inputs[]=0&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c", schema.to_s
  end
  
  def test_remove_does_not_create_nodes_for_out_of_bounds_indicies
    path = prepare_schema(0, "a")
    assert_equal 302, request.post("/0?action=remove&inputs[]=0&inputs[]=1&outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a", schema.to_s
  end
end
