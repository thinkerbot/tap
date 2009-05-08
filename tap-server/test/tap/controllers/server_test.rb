require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/server'

class Tap::Controllers::ServerTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_tap_test
  acts_as_subset_test
  cleanup_dirs << :views << :public
  
  attr_reader :server, :opts, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @opts = {'tap.server' => @server}
    @request = Rack::MockRequest.new(Tap::Controllers::Server)
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
    e = assert_raises(Tap::Server::ServerError) { request.get("/page.html", opts) }
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
  
  #
  # config test
  #
  
  def test_config_returns_public_configs_as_xml
    server.secret = "1234"
    response = request.get("/config/1234", opts)
    
    assert_equal 'text/xml', response['Content-Type']
    assert_match(/<uri>#{server.uri('tap/controllers/server')}<\/uri>/, response.body)
    assert_match(/<secret>#{server.secret}<\/secret>/, response.body)
  end
  
end