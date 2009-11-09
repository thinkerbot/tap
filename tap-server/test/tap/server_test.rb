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
end
