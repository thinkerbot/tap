require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ServerTest < Test::Unit::TestCase
  Server = Tap::Server
  ServerError = Tap::Server::ServerError
  
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
end
