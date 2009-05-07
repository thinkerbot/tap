require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/client'
require 'webrick'
require 'stringio'

class Tap::App::ClientTest < Test::Unit::TestCase
  Client = Tap::App::Client
  
  def setup
    @timeout_error = false
  end
  
  def teardown
    super
    flunk "timeout error" if @timeout_error
  end
  
  # starts a WEBrick server on the host/port
  # yields to block
  # returns log of all activites
  def with_server(config={:Host => '127.0.0.1', :Port => 8080})
    monitor = Monitor.new
    io = StringIO.new
    logger = WEBrick::Log.new(io)
    
    config = {
      :Logger => logger,
      :AccessLog => [
        [ logger, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
        [ logger, WEBrick::AccessLog::REFERER_LOG_FORMAT ]]
    }.merge(config)
    
    server = WEBrick::HTTPServer.new(config)
    server.mount_proc("/") do |req, res|
      res['Content-Type'] = "text/plain"
      
      case req.path_info
      when "/pid/1234"  # pid with secret
        res.body << "8"
      else
        res.body << ""
      end
    end
    
    begin
      Thread.new do
        sleep(3); 
        monitor.synchronize do
          if server.status == :Running
            server.shutdown
          end
        end
        @timeout_error = true
      end
      
      Thread.new { server.start }
      
      yield
    ensure
      monitor.synchronize do
        if server.status == :Running
          server.shutdown
        end
      end
    end
    
    io.string
  end
  
  def test_mock_server_returns_8_with_secret_and_empty_str_without
    with_server do
      assert_equal "", Net::HTTP.get('127.0.0.1', "/pid/", 8080)
      assert_equal "8", Net::HTTP.get('127.0.0.1', "/pid/1234", 8080)
    end
  end
  
  #
  # connect test
  #
  
  def test_connect_returns_nil_if_no_connection_is_established
    assert_equal nil, Client.connect
  end
  
  def test_connect_returns_new_client_for_existing_server
    with_server do
      client = Client.connect
      assert_equal Client, client.class
      assert_equal 0, client.pid
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize_raise_error_if_no_connection_can_be_made
    err = assert_raises(Client::ConnectionError) { Client.new("127.0.0.1", 8080) }
    assert_equal "could not reach server: 127.0.0.1:8080", err.message
  end
  
  def test_initialize_sets_pid_with_server_pid
    with_server do
      client = Client.new("127.0.0.1", 8080)
      assert_equal 0, client.pid
      
      client = Client.new("127.0.0.1", 8080, 1234)
      assert_equal 8, client.pid
    end
  end
  
  def test_initialize_with_alternate_port
    with_server(:Port => 10000) do
      client = Client.new("127.0.0.1", 10000, 1234)
      assert_equal 8, client.pid
    end
  end
end