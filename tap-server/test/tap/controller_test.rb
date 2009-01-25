require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :public << :views

  #
  # setup
  #

  attr_accessor :server, :opts
  
  def setup
    super
    @server =  Tap::Server.new(:env => Tap::Env.new(method_root))
    @opts = {'tap.server' => server}
  end
  
  def assert_body(res, str)
    assert_alike Tap::Test::RegexpEscape.new(str.strip, Regexp::MULTILINE), res.body
  end
  
  #
  # call test
  #
  
  class ActionController < Tap::Controller
    def action
      "body"
    end
  end
  
  def test_call_routes_first_path_segment_as_action
    request = Rack::MockRequest.new(ActionController)
    assert_equal "body", request.get('/action', opts).body
    assert_equal "body", request.get('/action/page', opts).body
  end
  
  def test_call_returns_static_page_for_public_pages
    method_root.prepare(:public, 'page.html') {|file| file << "html page content"}
    method_root.prepare(:public, 'nested/page.html') {|file| file << "nested page content"}
    
    request = Rack::MockRequest.new(Tap::Controller)
    assert_equal "html page content", request.get('/page.html', opts).body
    assert_equal "nested page content", request.get('/nested/page.html', opts).body
  end
  
  def test_call_sets_mime_type_for_public_content
    method_root.prepare(:public, 'page.html') {|file| }
    method_root.prepare(:public, 'page.css') {|file| }
    
    request = Rack::MockRequest.new(Tap::Controller)
    assert_equal "text/html", request.get('/page.html', opts)["Content-Type"]
    assert_equal "text/css", request.get('/page.css', opts)["Content-Type"]
  end
  
  def test_call_returns_404_response_for_unknown_get
    method_root.prepare(:views, '404.erb') {|file| file << "404 Error"}
    
    request = Rack::MockRequest.new(Tap::Controller)
    assert_body request.get('/unknown/path', opts), "404 Error"
  end
  
  def test_call_returns_404_response_for_unknown_post
    method_root.prepare(:views, '404.erb') {|file| file << "404 Error"}
    
    request = Rack::MockRequest.new(Tap::Controller)
    assert_body request.post('/unknown/path', opts), "404 Error"
  end
end