require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/server'

class Tap::App::ServerTest < Test::Unit::TestCase
  acts_as_tap_test
  
  attr_accessor :server, :app, :request
  
  def setup
    super
    @server = Tap::App::Server.new
    @app = @server.app
    @request = Rack::MockRequest.new(server)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    server = Tap::App::Server.new
    assert_equal Tap::App, server.app.class
    assert_equal nil, server.thread
    assert_equal({}, server.nodes)
  end
  
  #
  # state test
  #
  
  def test_app_bq
    was_in_block = false
    app.bq { was_in_block = true }
    
    assert !was_in_block
    app.run
    assert was_in_block
  end
  
  def test_state_returns_app_state
    assert_equal "0", request.get("/state").body
    
    was_in_block = false
    hold = true
    app.bq do
      was_in_block = true
      sleep(0.01) while hold
    end
    
    thread = Thread.new { app.run }
    sleep(0.01)
    
    assert_equal "1", request.get("/state").body
    assert_equal true, was_in_block
    
    hold = false
    thread.join
    
    assert_equal "0", request.get("/state").body
  end
  
  #
  # info test
  #
  
  def test_info_contains_app_info_and_controls
    body = request.get("/info").body
    assert body =~ /<form action="run".*?method="post">/
    assert body =~ /\(READY\) queue: 0/
  end
  
  #
  # run test
  #
  
  def test_run_redirects_to_info
    assert_equal "info", request.get("/run").headers['Location']
  end
  
  def test_run_does_not_run_on_get
    app.bq do 
      flunk "app ran"
    end
    
    request.get("/run")
    assert_equal nil, server.thread
    assert_equal 0, app.state
  end
  
  def test_run_runs_on_post
    was_in_block = false
    hold = true
    app.bq do 
      was_in_block = true
      sleep(0.1) while hold
    end
    
    assert_equal "info", request.post("/run").headers['Location']
    assert_equal Thread, server.thread.class
    
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    
    hold = false
    server.thread.join
    
    # check thread is cleaned up when run completes
    assert_equal nil, server.thread
    assert_equal 0, app.state
  end
  
  #
  # stop test
  #
  
  def test_stop_stops_a_running_app
    was_in_block = false
    node = app.node { was_in_block = true }
    node.on_complete {|result| app.enq(node) }
    app.enq(node)
    
    thread = Thread.new { app.run }
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    
    assert_equal "info", request.post("/stop").headers['Location']
    thread.join
    
    assert_equal 1, app.queue.size
    assert_equal 0, app.state
  end
  
  def test_stop_does_not_stop_unless_post
    was_in_block = false
    node = app.node do 
      was_in_block = true
      app.check_terminate
    end
    
    node.on_complete {|result| app.enq(node) }
    app.enq(node)
    
    thread = Thread.new { app.run }
    sleep(0.01)
    assert_equal "info", request.get("/stop").headers['Location']
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    
    app.terminate
    thread.join
    
    assert_equal 0, app.state
  end
  
  #
  # terminate test
  #
  
  def test_terminate_terminates_a_running_app
    was_in_block = false
    app.bq do
      was_in_block = true
      while true
        sleep(0.01)
        app.check_terminate
      end
    end
    
    thread = Thread.new { app.run }
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    
    assert_equal "info", request.post("/terminate").headers['Location']
    thread.join
    
    assert_equal 0, app.state
  end
  
  def test_terminate_does_not_terminate_unless_post
    was_in_block = false
    hold = true
    app.bq do 
      while hold
        sleep(0.01)
        app.check_terminate
      end
      was_in_block = true
    end
    
    thread = Thread.new { app.run }
    sleep(0.01)
    assert_equal "info", request.get("/terminate").headers['Location']
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal false, was_in_block
    
    hold = false
    thread.join
    
    assert_equal 0, app.state
    assert_equal true, was_in_block
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
  
  def test_shutdown_terminates_a_running_app_then_stops_server
    handler = MockHandler.new
    server.run!(handler)
    assert_equal handler, server.handler
    
    was_in_block = false
    app.bq do
      was_in_block = true
      while true
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
    
    request.post("/shutdown")
    
    assert_equal 0, app.state
    assert_equal nil, server.thread
    assert_equal nil, server.handler
  end
  
  def test_shutdown_does_not_terminate_or_stop_unless_post
    handler = MockHandler.new
    server.run!(handler)
    assert_equal handler, server.handler
    
    was_in_block = false
    hold = true
    app.bq do
      sleep(0.01) while hold
      was_in_block = true
    end
    
    request.post("/run")
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal false, was_in_block
    assert_equal Thread, server.thread.class
    assert_equal handler, server.handler
    
    request.get("/shutdown")
    
    assert_equal 1, app.state
    assert_equal false, was_in_block
    assert_equal Thread, server.thread.class
    assert_equal handler, server.handler
    
    hold = false
    sleep(0.01)
    
    assert_equal 0, app.state
    assert_equal true, was_in_block
    assert_equal nil, server.thread
    assert_equal handler, server.handler
  end
end