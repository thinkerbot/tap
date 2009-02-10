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
    method_root.prepare(:views, "layouts/default.erb") do |file|
      file << "<%= content %>"
    end
    method_root.prepare(:views, "schema/schema.erb") do |file|
      file << "<%= id %>: <%= schema.to_s %>"
    end
    
    response = request.get("/display/0", opts)
    assert_equal "0: -- tap:task a b c --*0", response.body
  end
  
  #
  # add test
  #
  
  def prepare_schema(id, str)
    method_root.prepare(:schema, "#{id}.yml") do |file|
      file << Schema.parse(str).dump.to_yaml
    end
  end
  
  def test_post_add_adds_nodes_in_the_nodes_parameter
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=tap%3Atask", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task --*0", schema.to_s
  end
  
  def test_add_may_specify_multiple_nodes
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=a&nodes[]=b", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b --*0 --*1", schema.to_s
  end
  
  def test_add_node_is_split_into_and_argv_using_shellwords
    path = prepare_schema(0, "")
    assert_equal 302, request.post("/add/0?nodes[]=tap%3atask%20a%20b%20c", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- tap:task a b c --*0", schema.to_s
  end
  
  def test_add_joins_one_source_to_one_target_as_sequence
    path = prepare_schema(0, "a -- b")
    assert_equal 302, request.post("/add/0?sources[]=0&targets[]=1", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b --0:1", schema.to_s
  end
  
  def test_add_joins_one_source_to_many_target_as_fork
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/add/0?sources[]=0&targets[]=1&targets[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --0[1,2]", schema.to_s
  end
  
  def test_add_joins_many_sources_to_one_target_as_merge
    path = prepare_schema(0, "a -- b -- c")
    assert_equal 302, request.post("/add/0?sources[]=0&sources[]=1&targets[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c --2{0,1}", schema.to_s
  end
  
  def test_add_raises_error_for_many_sources_to_many_targets
    path = prepare_schema(0, "a -- b -- c -- d")
    err = assert_raises(Tap::ServerError) do
      request.post("/add/0?sources[]=0&sources[]=1&targets[]=2&targets[]=3", opts)
    end
    
    assert_equal "multi-join specified: [0, 1] => [2, 3]", err.message
  end
  
  def test_add_sets_join_output_to_nil_for_sources_without_a_target
    path = prepare_schema(0, "a -- b -- c -- d --0{1,2,3}")
    assert_equal 302, request.post("/add/0?sources[]=1&sources[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --*1 --*2 --0{3}}", schema.to_s
  end
  
  def test_add_sets_join_input_to_nil_for_targets_without_a_source
    path = prepare_schema(0, "a -- b -- c -- d --0[1,2,3]")
    assert_equal 302, request.post("/add/0?targets[]=1&targets[]=2", opts).status
    
    schema = Schema.load_file(path)
    assert_equal "-- a -- b -- c -- d --*1 --*2 --0[3]", schema.to_s
  end
  
end
