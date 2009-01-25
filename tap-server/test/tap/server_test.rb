require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'
require 'tap/test/regexp_escape'

class ServerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :controllers
  
  #
  # setup
  #
  
  attr_accessor :server, :request
  
  def setup
    super
    @server = Tap::Server.new(:env => Tap::Env.new(method_root))
    @request = Rack::MockRequest.new(@server)
  end
  
  def assert_body(res, str)
    assert_alike Tap::Test::RegexpEscape.new(str.strip, Regexp::MULTILINE), res.body
  end
  
  #
  # METHOD_URI test
  #
  
  def test_METHOD_URI
    r = Tap::Server::METHOD_URI
    
    assert r =~ "get@str"
    assert_equal ['get', "str"], [$1, $2]
    
    assert r =~ "post@str"
    assert_equal ['post', "str"], [$1, $2]
    
    assert r =~ "get@str@with@ts"
    assert_equal ['get', "str@with@ts"], [$1, $2]
    
    assert r =~ "post@str@with@ts"
    assert_equal ['post', "str@with@ts"], [$1, $2]
    
    assert r !~ "str@with@ts"
  end
  
  #
  # CONTROLLER_ROUTE test
  #
  
  def test_CONTROLLER_ROUTE
    r = Tap::Server::CONTROLLER_ROUTE
    
    assert r =~ "/"
    assert_equal ['', nil], [$1, $2]
    
    assert r =~ "/key"
    assert_equal ['key', nil], [$1, $2]
    
    assert r =~ "/key/"
    assert_equal ['key', '/'], [$1, $2]
    
    assert r =~ "/key/a/b/c"
    assert_equal ['key', '/a/b/c'], [$1, $2]
    
    assert r =~ "/key/a/b/c/"
    assert_equal ['key', '/a/b/c/'], [$1, $2]
    
  end
  
  #
  # call tests
  #
  
  class MockController
    def self.call(env)
      [200, {}, "#{self}: #{env['PATH_INFO']}"]
    end
  end
  
  def test_call_routes_to_controllers
    server.controllers['route'] = MockController
    
    assert_body request.get('/route'), "ServerTest::MockController: /"
    assert_body request.get('/route/page'), "ServerTest::MockController: /page"
  end
  
  def test_call_routes_to_env_controllers
    method_root.prepare(:controllers, 'sample_route_controller.rb') do |file| 
      file << %q{
        class SampleRouteController < ServerTest::MockController
        end
      }
    end
    
    assert_body request.get('/sample_route'), "SampleRouteController: /"
    assert_body request.get('/sample_route/page'), "SampleRouteController: /page"
  end
  
  def test_call_routes_controller_aliases_to_env_controllers
    method_root.prepare(:controllers, 'sample_alias_controller.rb') do |file| 
      file << %q{
        class SampleAliasController < ServerTest::MockController
        end
      }
    end
    
    server.controllers['alias'] = 'sample_alias'
    
    assert_body request.get('/alias'), "SampleAliasController: /"
    assert_body request.get('/alias/page'), "SampleAliasController: /page"
  end
  
  def test_call_routes_unknown_paths_to_app_controller_by_default
    method_root.prepare(:controllers, 'app_controller.rb') do |file| 
      file << %q{
        class AppController < ServerTest::MockController
        end}
    end
    
    assert_body request.get('/unknown'), "AppController: /"
    assert_body request.get('/unknown'), "AppController: /unknown"
    assert_body request.get('/unknown/page'), "AppController: /unknown/page"
  end
  
  class UnhandledErrorController
    attr_accessor :err
    def initialize
      begin
        raise "error"
      rescue
        @err = $!
      end
    end
    
    def call(env)
      raise err
    end
  end
  
  def test_call_handles_unhandled_errors
    controller = UnhandledErrorController.new
    err = controller.err
    server.controllers['err'] = controller
    
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}", res.body
  end
  
  #
  # process test
  #
  
  def test_
    server.controllers['mock'] = MockController
    
    assert_equal "ServerTest::MockController: /", server.process("mock").body
    assert_equal "ServerTest::MockController: /path", server.process("mock/path").body
  end
end
