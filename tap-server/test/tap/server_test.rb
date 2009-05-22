require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ServerTest < Test::Unit::TestCase
  Server = Tap::Server
  ServerError = Tap::Server::ServerError
  
  acts_as_file_test
  cleanup_dirs << :root
  
  attr_reader :controller, :env, :server, :request
  
  def setup
    super
    @controller = lambda {|env| [200, {}, ['controller']]}
    @env = Tap::Env.new(:root => method_root, :gems => :none)
    @env.activate
    
    @server = Server.new(controller, :env => env)
    @request = Rack::MockRequest.new(@server)
  end
  
  def teardown
    super
    @env.deactivate
  end
  
  #
  # initialize test
  #
  
  def test_initialize_sets_env_to_pwd
    server = Server.new
    assert_equal Dir.pwd, server.env.root.root
  end
  
  #
  # call tests
  #
  
  def test_call_routes_to_controller
    controller = lambda {|env| [200, {}, ["result"]]}
    request = Rack::MockRequest.new(Server.new(controller))
    
    assert_equal "result", request.get('/route').body
  end

  class RegisteredController
    def self.call(env)
      [200, {}, ['result']]
    end
  end
  
  def test_call_routes_to_registered_controller
    env.register_constant(:controller, RegisteredController)
    
    assert_equal RegisteredController, server.env[:controller]['registered_controller']
    assert_equal "result", request.get('/registered_controller').body
  end
  
  class AdjustController
    def self.call(env)
      headers = {'script_name' => env['SCRIPT_NAME'], 'path_info' => env['PATH_INFO']}
      [200, headers, [""]]
    end
  end
  
  def test_call_adjusts_env_to_reflect_reroute
    env.register_constant(:controller, AdjustController)
  
    headers = request.get("/adjust_controller").headers
    assert_equal ["/adjust_controller"], headers['script_name']
    assert_equal ["/"], headers['path_info']
    
    headers = request.get("/adjust_controller/path").headers
    assert_equal ["/adjust_controller"], headers['script_name']
    assert_equal ["/path"], headers['path_info']
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    env.register_constant(:controller, AdjustController)
    
    headers = request.get("/%61djust_controller/a%2Bb/c%20d")
    assert_equal ["/%61djust_controller"], headers['script_name']
    assert_equal ["/a%2Bb/c%20d"], headers['path_info']
  end
  
  class EnvController
    def self.call(env)
      [200, {}, [env['tap.server'].object_id.to_s]]
    end
  end
  
  def test_call_adds_self_to_rack_env_as_tap_dot_server
    server.controller = EnvController
    assert_equal server.object_id.to_s, request.get("/route").body
  end
 
  def test_call_returns_500_for_unhandled_error
    err = Exception.new "message"
    controller = lambda {|env| raise err }
    request = Rack::MockRequest.new(Server.new(controller))
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}", res.body
  end
  
  def test_call_returns_response_for_ServerErrors
    controller = lambda {|env| raise ServerError.new("msg") }
    request = Rack::MockRequest.new(Server.new(controller))
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "msg", res.body
  end
  
  def test_call_returns_404_when_no_controller_can_be_found
    server.controller = nil
    
    res = request.get('/unknown')
    assert_equal 404, res.status
    assert_equal "404 Error: could not route to controller", res.body
  end
  
end
