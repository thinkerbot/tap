require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'schema_controller'

class SchemaControllerUtilsTest < Test::Unit::TestCase
  include SchemaController::Utils
  
  #
  # pair_parse test
  #
  
  def test_pair_parse_collects_ordinary_key_value_pairs
    assert_equal({'key' => ['value']}, pair_parse('key' => ['value']))
    assert_equal({'key' => ['a', 'b', 'c']}, pair_parse('key' => ['a', 'b', 'c']))
  end
  
  def test_pair_parse_parses_url_encoded_hashes
    assert_equal({'key' => {'key' => ['value']}}, pair_parse('key[key]' => ['value']))
  end
  
  def test_pair_parse_parses_url_encoded_arrays
    assert_equal({'key' => [['a', 'b', 'c']]}, pair_parse('key[]' => ['a', 'b', 'c']))
  end
  
  def test_pair_parse_shellword_splits_values_keyed_with_a_percent_sign_w
    assert_equal({'key' => ['a', 'b', 'c']}, pair_parse('key%w' => 'a b c'))
  end
  
  def test_pair_parse_concatenates_shellword_and_ordinary_array_values
    assert_equal ['a', 'b', 'c', 'value'].sort, pair_parse('key%w' => 'a b c', 'key' => ['value'])['key'].sort
  end
end

class SchemaControllerTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_tap_test
  cleanup_dirs << :schema << :log << :views
  
  attr_reader :server, :opts, :controller, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @opts = {'tap.server' => @server}
    @controller = SchemaController.new
    @request = Rack::MockRequest.new(@controller)
  end
  
  def prepare_schema(id, str)
    method_root.prepare(:schema, "#{id}.yml") do |file|
      file << Schema.parse(str).dump.to_yaml
    end
  end
  
  #
  # index tests
  #
  
  def test_get_index_initializes_new_schema
    assert method_root.glob(:schema, "*").empty?
    request.get("/", opts)
    assert !method_root.glob(:schema, "*").empty?
  end
  
  def test_get_index_redirects_to_display_new_schema
    response = request.get("/", opts)
    
    schema_file = method_root.glob(:schema, "*")[0]
    schema_id = File.basename(schema_file).chomp(".yml")
    
    assert_equal 302, response.status
    assert_equal "/schema/display/#{schema_id}", response['Location']
  end
  
  #
  # display test
  #
  
  def test_get_display_loads_and_renders_the_specified_schema
    method_root.prepare(:schema, "0.yml") do |file|
      file << Schema.parse("tap:task a b c").dump.to_yaml
    end
    
    # fake out display templates
    method_root.prepare(:views, "layout.erb") do |file|
      file << "<%= content %>"
    end
    method_root.prepare(:views, "schema_controller/schema.erb") do |file|
      file << "<%= id %>: <%= schema.to_s %>"
    end
    
    response = request.get("/display/0", opts)
    assert_equal "0: -- tap:task a b c", response.body
  end
  
  #
  # add test
  #
  
  def test_post_add_adds_nodes_in_the_nodes_parameter
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=tap%3Atask", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task", schema.to_s
  end
  
  def test_add_may_specify_multiple_nodes
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=a&nodes[]=b", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b", schema.to_s
  end
  
  def test_add_node_is_split_into_and_argv_using_shellwords
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=tap%3atask%20a%20b%20c", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task a b c", schema.to_s
  end
  
  def test_add_joins_one_input_to_one_output_as_sequence
    path = prepare_schema(0, "a -- b")
    assert_equal 302, request.post("/add/0?inputs[]=0&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b --0:1", schema.to_s
  end
  
  def test_add_joins_one_input_to_many_output_as_fork
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/add/0?inputs[]=0&outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --0[1,2]", schema.to_s
  end
  
  def test_add_joins_many_inputs_to_one_output_as_merge
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/add/0?inputs[]=0&inputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --2{0,1}", schema.to_s
  end
  
  # def test_add_allows_many_inputs_to_many_outputs_join
  #   path = prepare_schema(0, "a -- b -- c -- d")
  #   assert_equal 302, request.post("/add/0?inputs[]=0&inputs[]=1&outputs[]=2&outputs[]=3", opts).status
  #   
  #   schema = Schema.load_file(path)
  #   assert_equal "-- a -- b -- c -- d --2{0,1}", schema.to_s
  # end
  
  def test_add_sets_join_output_to_nil_for_inputs_without_a_output
    path = prepare_schema(0, "a -- b -- c -- d --0{1,2,3}")
    assert_equal 302, request.post("/add/0?inputs[]=1&inputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --3:0", schema.to_s
  end
  
  def test_add_sets_join_input_to_nil_for_outputs_without_a_input
    path = prepare_schema(0, "a -- b -- c -- d --0[1,2,3]")
    assert_equal 302, request.post("/add/0?outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --0:3", schema.to_s
  end
  
  #
  # remove test
  #
  
  def test_post_remove_removes_nodes_indicated_in_both_inputs_and_outputs
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/remove/0?inputs[]=1&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- c", schema.to_s
  end
  
  def test_remove_removes_join_outputs_for_inputs
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/remove/0?inputs[]=0", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --1:2", schema.to_s
  end
  
  def test_remove_removes_join_inputs_for_outputs
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/remove/0?outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --0[] --1:2", schema.to_s
  end
  
  def test_remove_removes_join_and_not_node_when_joins_exist
    path = prepare_schema(0, "a -- b -- c --0:1:2")
    assert_equal 302, request.post("/remove/0?inputs[]=1&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --0[]", schema.to_s
  end
  
  def test_remove_does_not_remove_nodes_unless_indicated_in_both_inputs_and_outputs
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/remove/0?inputs[]=0&outputs[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c", schema.to_s
  end
  
  def test_remove_does_not_create_nodes_for_out_of_bounds_indicies
    path = prepare_schema(0, "a")
    assert_equal 302, request.post("/remove/0?inputs[]=0&inputs[]=1&outputs[]=1&outputs[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a", schema.to_s
  end
end
