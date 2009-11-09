require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/server'

class Tap::Controllers::ServerTest < Test::Unit::TestCase
  acts_as_tap_test :cleanup_dirs => [:tmp, :views, :public]
  
  attr_reader :server, :request
  
  def setup
    super
    @server = Tap::Server.new.bind(Tap::Controllers::Server)
    @request = Rack::MockRequest.new(@server)
  end
  
  def env_config
    config = super
    config[:env_paths] = TEST_ROOT
    config
  end
  
  #
  # ping test
  #
  
  def test_ping_returns_pong
    response = request.get("/server/ping")
    
    assert_equal 'text/plain', response['Content-Type']
    assert_equal "pong", response.body
  end
  
  #
  # call test
  #
  
  def test_call_redirects_to_self_for_unknown_controller
    response = request.get("/unknown")
    
    assert_equal 302, response.status
    assert_equal "/server/unknown", response['Location']
  end
  
  def test_call_serves_public_pages
    method_root.prepare(:public, "page.html") {|file| file << "<html></html>" }
    response = request.get("/page.html")
    
    assert_equal 200, response.status
    assert_equal "<html></html>", response.body
  end
  
  def test_call_serves_nested_public_pages
    method_root.prepare(:public, "dir/page.html") {|file| file << "<html>dir</html>" }
    assert_equal "<html>dir</html>", request.get("/dir/page.html").body
  end
  
  def test_call_serves_public_pages_from_nested_envs
    assert_equal 302, request.get("/page.html").status
    
    nested_env = Tap::Env.new(method_root[:tmp])
    nested_env.root.prepare(:public, "page.html") {|file| file << "<html></html>" }
    server.env.push nested_env
    
    assert_equal "<html></html>", request.get("/page.html").body
  end
  
  def test_call_negotiates_public_page_content_type_by_extname
    method_root.prepare(:public, "page.html") {|file| }
    assert_equal "text/html", request.get("/page.html").content_type
    
    method_root.prepare(:public, "page.txt") {|file| }
    assert_equal "text/plain", request.get("/page.txt").content_type
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
    assert_equal "/registered_controller", headers['script_name']
    assert_equal "/", headers['path_info']

    headers = request.get("/registered_controller/path").headers
    assert_equal "/registered_controller", headers['script_name']
    assert_equal "/path", headers['path_info']
  end

  def test_call_correctly_routes_path_info_with_escapes
    server.env.register(RegisteredController)

    headers = request.get("/%72egistered_controller/a%2Bb/c%20d")
    assert_equal "/%72egistered_controller", headers['script_name']
    assert_equal "/a%2Bb/c%20d", headers['path_info']
  end
end