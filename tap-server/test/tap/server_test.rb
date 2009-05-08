require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ServerTest < Test::Unit::TestCase
  Server = Tap::Server
  ServerError = Tap::Server::ServerError
  
  acts_as_tap_test
  cleanup_dirs << :root
  
  attr_reader :env, :server, :request
  
  def setup
    super
    @env = Tap::Env.new(:root => method_root, :gems => :none)
    @env.activate
    @server = Server.new @env
    @request = Rack::MockRequest.new(@server)
  end
  
  def teardown
    super
    @env.deactivate
  end
  
  #
  # documentation test
  #
  
  def test_documentation
    server = Server.new(env)
    server.controllers['sample'] = lambda do |env|
      [200, {}, ["Sample got #{env['SCRIPT_NAME'].inspect} : #{env['PATH_INFO'].inspect}"]]
    end
  
    req = Rack::MockRequest.new(server)
    assert_equal "Sample got [\"/sample\"] : [\"/path/to/resource\"]", req.get('/sample/path/to/resource').body
  
    method_root.prepare('lib/example.rb') do |file| 
      file << %q{
# ::controller
class Example
  def self.call(env)
    [200, {}, ["Example got #{env['SCRIPT_NAME'].inspect} : #{env['PATH_INFO'].inspect}"]]
  end
end 
}
    end
  
    assert_equal "Example got [\"/example\"] : [\"/path/to/resource\"]", req.get('/example/path/to/resource').body
  
    server.controllers['sample'] = 'example'
    assert_equal "Example got [\"/sample\"] : [\"/path/to/resource\"]", req.get('/sample/path/to/resource').body 
    
    server.default_controller_key = 'app'
    server.controllers['app'] = lambda do |env|
      [200, {}, ["App got #{env['SCRIPT_NAME'].inspect} : #{env['PATH_INFO'].inspect}"]]
    end
  
    assert_equal "App got \"\" : \"/unknown/path/to/resource\"", req.get('/unknown/path/to/resource').body
  end

  #
  # initialize test
  #
  
  def test_initialize_sets_env_to_pwd
    server = Server.new
    assert_equal Dir.pwd, server.env.root.root
  end
  
  #
  # initialize_session test
  #
  
  def test_initialize_session_returns_zero_if_use_multiple_sessions_is_false
    assert_equal false, server.use_multiple_sessions
    assert_equal 0, server.initialize_session
    assert_equal 0, server.initialize_session
  end
  
  def test_initialize_session_returns_new_session_id_when_use_multiple_sessions_is_true
    server.use_multiple_sessions = true
    
    ids = []
    10.times do 
      ids << server.initialize_session
    end
    
    assert_equal ids, ids.uniq
  end
  
  #
  # session test
  #
  
  def test_session_sets_up_session_for_the_id
    assert server.session(0).kind_of?(Tap::Server::Session)
  end
  
  def test_session_uses_app_instance_by_default
    assert_equal Tap::App.instance, server.session(0).app
  end
  
  def test_session_persistence_is_initialized_using_env_root_configs
    server.env.root.relative_paths = {:key => 'value'}
    assert_equal({:key => 'value'}, server.session(0).persistence.relative_paths)
  end
  
  def test_session_creates_persistence_root
    server.use_multiple_sessions = true
    zero = server.session(0)
    one = server.session(1)
    
    assert_equal "0", File.basename(zero.persistence.root)
    assert_equal "1", File.basename(one.persistence.root)
    
    assert File.directory?(zero.persistence.root)
    assert File.directory?(one.persistence.root)
  end
  
  def test_session_persistence_is_initialized_to_env_root_if_use_multiple_sessions_is_false
    assert_equal false, server.use_multiple_sessions
    assert_equal server.env.root.root, server.session(0).persistence.root
    assert_equal server.env.root.root, server.session(1).persistence.root
  end
  
  def test_session_loads_from_existing_session_data
    assert_equal({}, server.session(0).persistence.relative_paths)
    
    method_root.prepare(:root, 'session.yml') do |io|
      io << YAML.dump(:persistence => {
        :relative_paths => {:key => 'value'}
      })
    end
    assert_equal({:key => 'value'}, server.session(0).persistence.relative_paths)
  end
  
  #
  # call tests
  #
  
  class RegisteredController
    def initialize(body)
      @body = body
    end
    def call(env)
      [200, {}, [@body]]
    end
  end
  
  def test_call_routes_to_registered_controller
    server.controllers['route'] = RegisteredController.new("result")
    assert_equal "result", request.get('/route').body
  end
  
  class AdjustController
    def self.call(env)
      headers = {'script_name' => env['SCRIPT_NAME'], 'path_info' => env['PATH_INFO']}
      [200, headers, [""]]
    end
  end
  
  def test_call_adjusts_env_to_reflect_reroute
    server.controllers['route'] = AdjustController
    
    headers = request.get("/route").headers
    assert_equal ["/route"], headers['script_name']
    assert_equal ["/"], headers['path_info']
    
    headers = request.get("/route/path").headers
    assert_equal ["/route"], headers['script_name']
    assert_equal ["/path"], headers['path_info']
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    server.controllers['action'] = AdjustController
    
    headers = request.get("/%61ction/a%2Bb/c%20d")
    assert_equal ["/%61ction"], headers['script_name']
    assert_equal ["/a%2Bb/c%20d"], headers['path_info']
  end
  
  class EnvController
    def self.call(env)
      [200, {}, [env['tap.server'].object_id.to_s]]
    end
  end

  def test_call_adds_server_to_env
    server.controllers['route'] = EnvController
    assert_equal server.object_id.to_s, request.get("/route").body
  end
  
  class RouteController
    def self.call(env)
      [200, {}, [to_s]]
    end
  end
  
  def test_call_routes_to_env_controllers
    method_root.prepare(:lib, 'sample_route.rb') do |file| 
      file << %Q{# ::controller\nclass SampleRoute < ServerTest::RouteController; end}
    end
  
    assert_equal "SampleRoute", request.get('/sample_route').body
    assert_equal "SampleRoute", request.get('/sample_route/page').body
  end
  
  def test_call_routes_using_env_controller_aliases
    method_root.prepare(:lib, 'sample_alias.rb') do |file| 
      file << %Q{# ::controller\nclass SampleAlias < ServerTest::RouteController; end}
    end
  
    server.controllers['alias'] = 'sample_alias'
    assert_equal "SampleAlias", request.get('/alias').body
    assert_equal "SampleAlias", request.get('/alias/page').body
  end
  
  def test_call_routes_unknown_to_server_controller
    method_root.prepare(:lib, 'app.rb') do |file| 
      file << %Q{# ::controller\nclass App < ServerTest::RouteController; end}
    end
    
    assert_equal "App", request.get('/').body
    assert_equal "App", request.get('/unknown').body
    assert_equal "App", request.get('/app').body
    assert_equal "App", request.get('/app/page').body
  end
  
  class ErrorController
    attr_accessor :err
    def initialize(err)
      @err = err
    end
    def call(env)
      raise err
    end
  end

  def test_call_returns_500_for_unhandled_error
    err = Exception.new "message"
    server.controllers['err'] = ErrorController.new(err)
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}", res.body
  end
  
  def test_call_returns_response_for_ServerErrors
    err = ServerError.new("msg")
    server.controllers['err'] = ErrorController.new(err)
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "msg", res.body
  end
  
  def test_call_returns_404_when_no_controller_can_be_found
    res = request.get('/unknown')
    assert_equal 404, res.status
    assert_equal "404 Error: could not route to controller", res.body
  end
end
