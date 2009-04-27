require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/schema'

class Tap::Controllers::SchemaTest < Test::Unit::TestCase
  Schema = Tap::Schema
  
  acts_as_tap_test
  cleanup_dirs << :data << :log << :views
  
  attr_reader :server, :opts, :controller, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @opts = {'tap.server' => @server}
    @controller = Tap::Controllers::Schema.new
    @request = Rack::MockRequest.new(@controller)
  end
  
  def prepare_schema(id, str)
    method_root.prepare(:data, id.to_s) do |file|
      file << Schema.parse(str).dump
    end
  end
  
  #
  # show test
  #
  
  def test_show_loads_and_renders_the_specified_schema
    method_root.prepare(:data, "0") do |file|
      file << Schema.parse("-- a 1 2 3 --+ b -- c --0:2").dump
    end
    
    # fake out display templates
    method_root.prepare(:views, "layout.erb") do |file|
      file << "<%= content %>"
    end
    method_root.prepare(:views, "tap/controllers/schema/schema.erb") do |file|
      file << "<%= id %>: <%= schema.to_s %>"
    end
    
    response = request.get("/0", opts)
    assert_equal "0: -- a 1 2 3 -- b -- c --+1[1] --[0][2]", response.body
  end
  
  #
  # add test
  #
  
  def test_add_adds_nodes_in_the_nodes_parameter
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/0?action=add&nodes[][id]=tap%3Atask", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task", schema.to_s
  end
  
  def test_add_may_specify_multiple_nodes
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/0?action=add&nodes[][id]=a&nodes[][id]=b", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b", schema.to_s
  end
  
  def test_add_node_is_split_into_and_argv_using_shellwords
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/0?action=add&nodes[][id]=tap%3atask&nodes[][args][]=a&nodes[][args][]=b&nodes[][args][]=c", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task a b c", schema.to_s
  end
  
  def test_add_joins_one_input_to_one_output_as_sequence
    path = prepare_schema(0, "a -- b")
    assert_equal 302, request.post("/0?action=add&inputs[]=0&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b --[0][1]", schema.to_s
  end
  
  def test_add_joins_one_input_to_many_output_as_fork
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/0?action=add&inputs[]=0&outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --[0][1,2]", schema.to_s
  end
  
  def test_add_joins_many_inputs_to_one_output_as_merge
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/0?action=add&inputs[]=0&inputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --[0,1][2]", schema.to_s
  end
  
  def test_add_sets_join_output_to_nil_for_inputs_without_a_output
    path = prepare_schema(0, "a -- b -- c -- d --[1,2,3][0]")
    assert_equal 302, request.post("/0?action=add&inputs[]=1&inputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --[3][0]", schema.to_s
  end
  
  def test_add_sets_join_input_to_nil_for_outputs_without_a_input
    path = prepare_schema(0, "a -- b -- c -- d --[0][1,2,3]")
    assert_equal 302, request.post("/0?action=add&outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --[0][3]", schema.to_s
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
