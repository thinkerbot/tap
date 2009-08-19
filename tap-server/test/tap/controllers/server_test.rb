require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/server'

class Tap::Controllers::ServerTest < Test::Unit::TestCase
  
  acts_as_tap_test
  acts_as_subset_test
  cleanup_dirs << :views << :public
  
  attr_reader :server, :request
  
  def setup
    super
    
    env.reconfigure(:root => method_root, :env_paths => TEST_ROOT)
    @server = Tap::Server.new Tap::Controllers::Server, :app => app
    @request = Rack::MockRequest.new(server)
  end
  
  #
  # ping test
  #
  
  def test_ping_returns_pong
    response = request.get("/ping")
    
    assert_equal 'text/plain', response['Content-Type']
    assert_equal "pong", response.body
  end
  
  #
  # call test
  #
  
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
    assert_equal "404 Error: page not found", request.get("/page.html").body
    
    nested_env = Tap::Env.new(method_root[:tmp])
    nested_env.root.prepare(:public, "page.html") {|file| file << "<html></html>" }
    env.push nested_env
    
    assert_equal "<html></html>", request.get("/page.html").body
  end
  
  def test_call_negotiates_public_page_content_type_by_extname
    method_root.prepare(:public, "page.html") {|file| }
    assert_equal "text/html", request.get("/page.html").content_type
    
    method_root.prepare(:public, "page.txt") {|file| }
    assert_equal "text/plain", request.get("/page.txt").content_type
  end
end