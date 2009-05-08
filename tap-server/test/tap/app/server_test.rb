require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/server'

class Tap::App::ServerTest < Test::Unit::TestCase
  acts_as_tap_test
  
  attr_accessor :server, :app, :request, :timeout
  
  def setup
    super
    @server = Tap::App::Server.new
    @app = @server.app
    @request = Rack::MockRequest.new(server)
    
    @timeout = Time.now + 3
    @timeout_error = false
  end

  def teardown
    super
    flunk "timeout error" if @timeout_error
  end

  def timeout?
    if Time.now > @timeout
      @timeout_error = true
      true
    else
      false
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    server = Tap::App::Server.new
    assert_equal Tap::App, server.app.class
    assert_equal nil, server.thread
    assert_equal({}, server.tasks)
  end
  
  #
  # info test
  #
  
  def test_info_contains_app_info_and_controls
    body = request.get("/info").body
    assert body =~ /<form action="\/run".*?method="post">/
    assert body =~ /\(READY\) queue: 0/
  end

  #
  # pid test
  #
  
  def test_pid_returns_pid_if_admin
    server.secret = "1234"
    assert_equal "", request.get("/pid").body
    assert_equal "", request.get("/pid/").body
    assert_equal "", request.get("/pid/4321").body
    assert_equal Process.pid.to_s, request.get("/pid/1234").body
  end
  
  #
  # build test
  #
  
  def test_build_returns_schema_form_on_get
    body = request.get("/build").body
    assert body =~ /<form action="\/build" method="post"/
    assert body =~ /<input type="submit"/
  end
  
  #
  # enque test
  #
  
  def test_enque_returns_enque_form_on_get
    body = request.get("/enque").body
    assert body =~ /<form action="\/enque" method="post"/
    assert body =~ /<input type="submit" value="enque"/
  end
  
  #
  # admin? test
  #
  
  def test_admin_is_false_if_secret_is_nil
    assert_equal nil, server.secret
    assert_equal false, server.admin?(nil)
    assert_equal false, server.admin?("1234")
  end
  
  def test_admin_is_true_if_input_equals_secret
    server.secret = "1234"
    assert_equal true, server.admin?("1234")
    assert_equal false, server.admin?(nil)
    assert_equal false, server.admin?("4321")
  end
  
  #
  # shutdown test
  #
  
  class MockHandler
    def run(*args)
      yield(self)
    end
    
    def stop
    end
  end
  
  def test_mock_handler
    handler = MockHandler.new
    server.run!(handler)
    assert_equal handler, server.handler
    
    server.stop!
    assert_equal nil, server.handler
  end
  
  def test_shutdown_terminates_a_running_app_then_stops_server_on_admin_post
    handler = MockHandler.new
    server.secret = "1234"
    server.run!(handler)
    
    was_in_block = false
    app.bq do
      was_in_block = true
      while !timeout?
        sleep(0.01)
        app.check_terminate
      end
      flunk "app was not terminated"
    end
    
    request.post("/run")
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    assert_equal Thread, server.thread.class
    assert_equal handler, server.handler
    
    request.get("/shutdown")
    sleep(0.3)
    
    assert_equal 1, app.state
    assert_equal Thread, server.thread.class
    assert_equal handler, server.handler
    
    request.post("/shutdown")
    sleep(0.3)
    
    assert_equal 1, app.state
    assert_equal Thread, server.thread.class
    assert_equal handler, server.handler
    
    request.post("/shutdown/1234")
    sleep(0.3)
    
    assert_equal 0, app.state
    assert_equal nil, server.thread
    assert_equal nil, server.handler
  end
end