require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/server'

class Tap::Controllers::ServerTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_tap_test
  
  attr_reader :server, :opts, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @opts = {'tap.server' => @server}
    @request = Rack::MockRequest.new(Tap::Controllers::Server)
  end
  
  #
  # ping test
  #
  
  def test_ping_returns_pong
    response = request.get("/ping", opts)
    
    assert_equal 'text/plain', response['Content-Type']
    assert_equal "pong", response.body
  end
  
  #
  # config test
  #
  
  def test_config_returns_public_configs_as_xml
    response = request.get("/config", opts)
    
    assert_equal 'text/xml', response['Content-Type']
    assert_match /<uri>#{server.uri('tap/controllers/server')}<\/uri>/, response.body
    assert_match /<shutdown_key>#{server.shutdown_key}<\/shutdown_key>/, response.body
  end
  
  #
  # shutdown test
  #
  
  class MockServer
    attr_reader :stop_called, :shutdown_key
    def initialize(shutdown_key=3)
      @shutdown_key = shutdown_key
      @stop_called = false
    end
    def stop!
      @stop_called = true
    end
  end
  
  def test_shutdown_calls_stop_on_server_if_shutdown_key_is_specified
    extended_test do
      server = MockServer.new
      assert_equal false, server.stop_called
    
      response = request.get("/shutdown?shutdown_key=3", 'tap.server' => server)
      assert_equal "shutdown", response.body
    
      # must sleep > 1 second since shutdown
      # waits 1 second before calling shutdown
      sleep 1.2
      assert_equal true, server.stop_called
    end
  end
  
  def test_shutdown_will_not_call_shutdown_for_wrong_shutdown_key
    extended_test do
      server = MockServer.new
      assert_equal false, server.stop_called
    
      response = request.get("/shutdown?shutdown_key=12", 'tap.server' => server)
      assert_equal "you do not have permission to shutdown this server", response.body
      
      sleep 1.2
      assert_equal false, server.stop_called
    end
  end
  
  def test_shutdown_will_not_call_shutdown_if_no_shutdown_key_is_set
    extended_test do
      server = MockServer.new(nil)
      assert_equal false, server.stop_called
    
      response = request.get("/shutdown?shutdown_key=", 'tap.server' => server)
      assert_equal "you do not have permission to shutdown this server", response.body
      
      sleep 1.2
      assert_equal false, server.stop_called
    end
  end
end