require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/app'

class Tap::Controllers::AppTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :views << :public
  
  attr_reader :server, :opts, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @opts = {'tap.server' => @server}
    @request = Rack::MockRequest.new(Tap::Controllers::App)
  end
  
  #
  # call test
  #
  
  def test_call_serves_public_pages
    method_root.prepare(:public, "page.html") {|file| file << "<html></html>" }
    response = request.get("/page.html", opts)
    
    assert_equal 200, response.status
    assert_equal "<html></html>", response.body
  end
  
  def test_call_serves_nested_public_pages
    method_root.prepare(:public, "dir/page.html") {|file| file << "<html>dir</html>" }
    assert_equal "<html>dir</html>", request.get("/dir/page.html", opts).body
  end
  
  def test_call_serves_public_pages_from_nested_envs
    e = assert_raises(Tap::ServerError) { request.get("/page.html", opts) }
    assert_equal "404 Error: page not found", e.message
    
    env = Tap::Env.new(method_root[:tmp])
    env.root.prepare(:public, "page.html") {|file| file << "<html></html>" }
    server.env.push env
    assert_equal "<html></html>", request.get("/page.html", opts).body
  end
  
  def test_call_negotiates_public_page_content_type_by_extname
    method_root.prepare(:public, "page.html") {|file| }
    assert_equal "text/html", request.get("/page.html", opts).content_type
    
    method_root.prepare(:public, "page.txt") {|file| }
    assert_equal "text/plain", request.get("/page.txt", opts).content_type
  end
  
end