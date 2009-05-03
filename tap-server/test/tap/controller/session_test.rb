require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controller/session'

class Tap::Controller::SessionTest < Test::Unit::TestCase
  acts_as_tap_test

  cleanup_dirs << :root

  attr_reader :controller, :server
  
  class SessionController < Tap::Controller
    include Session
    
    def action
      "response"
    end
  end
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
    @controller = SessionController.new
    @controller.server = server
  end

  #
  # call test
  #

  def test_call_sets_server
    controller = SessionController.new
    assert_equal nil, controller.server

    request = Rack::MockRequest.new controller
    request.get("/action", 'tap.server' => 'server')

    assert_equal 'server', controller.server
  end
  
  #
  # render test
  #
  
  class RenderController < Tap::Controller
    include Session
  end
  
  def test_render_renders_class_path_for_path
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    method_root.prepare(:views, 'tap/controller/session_test/session_controller/sample.erb') {|file| file << "<%= %w{one two three}.join(':') %>" }
  
    assert_equal "one:two:three", controller.render('sample.erb')
  
    render_controller = RenderController.new
    render_controller.server = server
    assert_equal "one:two", render_controller.render('sample.erb')
  end
  
  def test_render_looks_up_template_under_template_dir
    method_root.prepare(:views, 'alt/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    assert_equal "one:two", controller.render(:template => 'alt/sample.erb')
  end
  
  def test_render_renders_file
    path = method_root.prepare(:views, 'sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    assert_equal "one:two", controller.render(:file => path)
  end
  
  def test_render_renders_a_layout_template_with_content_if_specified
    method_root.prepare(:views, 'tap/controller/session_test/session_controller/layout.erb') {|file| file << "<html><%= content %></html>" }
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
  
    assert_equal "<html>one:two</html>", controller.render('sample.erb', :layout => 'layout.erb')
  end
  
  #
  # session test
  #
  
  def test_session_returns_the_rack_session
    session = {}
    request = Rack::Request.new Rack::MockRequest.env_for("/", 'rack.session' => session)
    controller.request = request
  
    assert_equal session.object_id, controller.session.object_id
  end
  
  def test_session_initializes_rack_session_as_a_hash_if_necessary
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    controller.request = request

    assert !request.env.has_key?('rack.session')
    session = controller.session
    assert_equal({:id => 0}, session)
    assert_equal session.object_id, request.env['rack.session'].object_id
  end
end