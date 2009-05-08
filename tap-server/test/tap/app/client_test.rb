require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/client'
require 'webrick'
require 'stringio'

class Tap::App::ClientTest < Test::Unit::TestCase
  Client = Tap::App::Client
  acts_as_subset_test
  skip_test
  
  def setup
    super
    @timeout_error = false
  end
  
  def teardown
    super
    flunk "timeout error" if @timeout_error
  end
  
  #
  # setup
  #
  
  # construct the command to invoke the app command.
  # this command redirects stderr to a tempfile simply
  # to suppress the launch output.
  root = File.expand_path(File.dirname(__FILE__) + "/../../..")
  load_paths = [
    "#{root}/../configurable/lib",
    "#{root}/../lazydoc/lib",
    "#{root}/../tap/lib",
    "#{root}/../rack/lib",
    "#{root}/../tap-server/lib",
  ].collect {|path| "-I'#{File.expand_path(path)}'" }.join(" ")
  cmd = File.expand_path("#{root}/cmd/app.rb")
  
  CMD = "ruby #{load_paths} '#{cmd}'"
  
  # a 'safe' server test ensuring any server threads are cleaned up
  def server_test
    extended_test do
      assert Thread.list.select {|t| t[:server] != nil }.empty?
    
      begin
        yield
      ensure
        # cleanup in case of error
        Thread.list.each do |thread| 
          if pid = thread[:server]
            Process.kill("INT", pid)
            thread.join
          end
        end
      end
    end
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
    # give a little time to release the socket (JRuby)
    sleep(1)
    
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
  # connect! test
  #
  
  def test_connect_bang_launches_background_server_if_no_connection_is_established
    server_test do
      log = []
      client = Client.connect!('127.0.0.1', 8080, :cmd => CMD, :log => log)
      assert_equal Client, client.class
      assert log[0] =~ /\+ 127\.0\.0\.1:8080\/ \(\d+\)/
    
      threads = Client.server_threads
      assert_equal 1, threads.length
      thread = threads[0]
    
      assert_equal thread[:server], client.pid
      assert Process.pid != client.pid
    
      Process.kill("INT", client.pid)
      thread.join
    
      assert_equal "- 127.0.0.1:8080 (0)\n", log[1]
    end
  end
  
  #
  # kill_servers! test
  #
  
  def test_kill_servers_stops_all_servers_running_on_live_threads
     server_test do
      log = []
      a = Client.connect!('127.0.0.1', 8080, :cmd => CMD, :log => log)
      b = Client.connect!('127.0.0.1', 8081, :cmd => CMD, :log => log)
      c = Client.connect!('127.0.0.1', 8082, :cmd => CMD, :log => log)
      
      Client.kill_servers!
      assert Thread.list.select {|t| t[:server] != nil }.empty?
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
      
      client = Client.new("127.0.0.1", 8080, :secret => 1234)
      assert_equal 8, client.pid
    end
  end
  
  def test_initialize_with_alternate_port
    with_server(:Port => 10000) do
      client = Client.new("127.0.0.1", 10000, :secret => 1234)
      assert_equal 8, client.pid
    end
  end
  
  #
  # kill_server! test
  #
  
  def test_kill_server_stops_server_running_on_pid
    server_test do
      log = []
      a = Client.connect!('127.0.0.1', 8080, :cmd => CMD, :log => log)
      b = Client.connect!('127.0.0.1', 8081, :cmd => CMD, :log => log)
      c = Client.connect!('127.0.0.1', 8082, :cmd => CMD, :log => log)
    
      assert_equal true, a.kill_server!
    
      servers = Client.server_threads
      assert_equal 2, servers.length
      assert_equal([b.pid, c.pid].sort, servers.collect {|t| t[:server]}.sort)
    
      assert_equal true, b.kill_server!
      assert_equal true, c.kill_server!
    
      assert_equal 0, Client.server_threads.length
    end
  end
  
  def test_kill_server_does_not_kill_servers_without_a_pid
    server_test do
      log = []
      a = Client.connect!('127.0.0.1', 8080, :cmd => CMD, :log => log, :secret => 1234)
      b = Client.connect('127.0.0.1', 8080)
      
      assert_equal 0, b.pid
      assert_equal false, b.kill_server!
      
      servers = Client.server_threads
      assert_equal 1, servers.length
      assert_equal(a.pid, servers[0][:server])
      
      assert_equal true, a.kill_server!
      
      assert_equal 0, Client.server_threads.length
    end
  end
  
  def test_kill_server_does_not_kill_servers_without_a_corresponding_thread
    server_test do
      log = []
      a = Client.connect!('127.0.0.1', 8080, :cmd => CMD, :log => log, :secret => 1234)
      thread = Thread.list.find {|t| t[:server] == a.pid }
      
      begin
        thread[:server] = nil
        assert_equal false, a.kill_server!
        assert thread.alive?
        
        thread[:server] = a.pid
        assert_equal true, a.kill_server!
        assert !thread.alive?
      ensure
        Process.kill("INT", a.pid) if thread.alive?
        thread.join
      end
    end
  end
end