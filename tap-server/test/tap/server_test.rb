require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ServerTest < Test::Unit::TestCase
  Server = Tap::Server
  ServerError = Tap::Server::ServerError
  
  acts_as_tap_test
  cleanup_dirs << :root
  
  attr_reader :server, :request
  
  def setup
    super
    @server = Server.new {|env| [200, {}, ['result']]}
    @request = Rack::MockRequest.new(@server)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    server = Server.new
    assert_equal app, server.app
  end
  
  #
  # call tests
  #
  
  def test_call_routes_to_server_block
    assert_equal "result", request.get('/route').body
  end
  
  def test_call_adds_self_to_rack_env_as_tap_dot_server
    server = Server.new {|env| [200, {}, [env['tap.server'].object_id.to_s]] }
    request = Rack::MockRequest.new(server)
    
    assert_equal server.object_id.to_s, request.get("/route").body
  end
   
  def test_call_returns_500_for_unhandled_error
    err = Exception.new "message"
    server = Server.new {|env| raise err }
    request = Rack::MockRequest.new(server)
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}", res.body
  end
  
  def test_call_returns_response_for_ServerErrors
    server = Server.new {|env| raise ServerError.new("msg") }
    request = Rack::MockRequest.new(server)
    
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "msg", res.body
  end
  
  #
  # routed calls
  #
  
  class RegisteredController
    def self.call(env)
      headers = {'script_name' => env['SCRIPT_NAME'], 'path_info' => env['PATH_INFO']}
      [200, headers, ['result']]
    end
  end
  
  def test_call_routes_to_registered_controller
    server.env.register(RegisteredController)
    assert_equal "result", request.get('/registered_controller').body
  end
  
  def test_call_adjusts_env_to_reflect_reroute
    server.env.register(RegisteredController)
    
    headers = request.get("/registered_controller").headers
    assert_equal ["/registered_controller"], headers['script_name']
    assert_equal ["/"], headers['path_info']
    
    headers = request.get("/registered_controller/path").headers
    assert_equal ["/registered_controller"], headers['script_name']
    assert_equal ["/path"], headers['path_info']
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    server.env.register(RegisteredController)
    
    headers = request.get("/%72egistered_controller/a%2Bb/c%20d")
    assert_equal ["/%72egistered_controller"], headers['script_name']
    assert_equal ["/a%2Bb/c%20d"], headers['path_info']
  end
  
  def test_call_returns_404_when_no_controller_can_be_found
    server = Server.new
    request = Rack::MockRequest.new(server)
    
    res = request.get('/unknown')
    assert_equal 404, res.status
    assert_equal "404 Error: could not route to controller", res.body
  end
end
