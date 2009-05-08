require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/api'

class Tap::App::ApiTest < Test::Unit::TestCase
  acts_as_tap_test
  
  class MockController < Tap::App::Api
    attr_accessor :admin, :stop_called
    
    def initialize(app)
      super(app)
      @admin = false
      @stop_called = false
    end
    
    def render(path, options)
      YAML.dump([path, options])
    end
    
    def admin?(input)
      @admin
    end
    
    def stop!
      @stop_called = true
    end
  end
  
  attr_accessor :controller, :app, :request, :timeout
  
  def setup
    super
    @app = Tap::App.new
    @controller = MockController.new app
    @request = Rack::MockRequest.new(controller)
    
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
    controller = Tap::App::Api.new
    assert_equal Tap::App, controller.app.class
    assert_equal nil, controller.thread
    assert_equal({}, controller.tasks)
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
      sleep(0.01) while hold && !timeout?
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
  # ping test
  #
  
  def test_ping_returns_pong
    response = request.get("/ping")
    
    assert_equal 'text/plain', response['Content-Type']
    assert_equal "pong", response.body
  end
  
  #
  # info test
  #
  
  def test_info_renders_infoerb
    path, options = YAML.load(request.get("/info").body)
    
    assert_equal 'info.erb', path
    assert_equal [:run, :stop, :terminate, :reset], options[:locals][:actions]
    assert_equal true, options[:layout]
  end
  
  def test_info_passes_secret_as_a_local
    path, options = YAML.load(request.get("/info").body)
    assert_equal nil, options[:locals][:secret]
    
    path, options = YAML.load(request.get("/info/1234").body)
    assert_equal '1234', options[:locals][:secret]
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
    assert_equal nil, controller.thread
    assert_equal 0, app.state
  end
  
  def test_run_runs_on_post
    was_in_block = false
    hold = true
    app.bq do 
      was_in_block = true
      sleep(0.1) while hold && !timeout?
    end
    
    assert_equal "info", request.post("/run").headers['Location']
    assert_equal Thread, controller.thread.class
    
    sleep(0.01)
    
    assert_equal 1, app.state
    assert_equal true, was_in_block
    
    hold = false
    controller.thread.join
    
    # check thread is cleaned up when run completes
    assert_equal nil, controller.thread
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
      while !timeout?
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
      while hold && !timeout?
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
  
  def test_shutdown_terminates_a_running_app_then_stops_server_on_admin_post
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
    assert_equal Thread, controller.thread.class
    assert_equal false, controller.stop_called
    
    request.get("/shutdown")
    sleep(0.3)
    
    assert_equal 1, app.state
    assert_equal Thread, controller.thread.class
    assert_equal false, controller.stop_called
    
    request.post("/shutdown")
    sleep(0.3)
    
    assert_equal 1, app.state
    assert_equal Thread, controller.thread.class
    assert_equal false, controller.stop_called
    
    controller.admin = true
    request.post("/shutdown")
    sleep(0.3)
    
    assert_equal 0, app.state
    assert_equal nil, controller.thread
    assert_equal true, controller.stop_called
  end
  
  #
  # build test
  #
  
  def test_build_renders_builderb_form_on_get
    path, options = YAML.load(request.get("/build").body)
    
    assert_equal 'build.erb', path
    assert_equal true, options[:layout]
  end
  
  #
  # enque test
  #
  
  def test_enque_renders_enqueerb_form_on_get
    path, options = YAML.load(request.get("/enque").body)
    
    assert_equal 'enque.erb', path
    assert_equal true, options[:layout]
  end
  
end