require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'
require 'tap/test/regexp_escape'

class ServerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :controllers
  
  attr_accessor :server, :request
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
    @request = Rack::MockRequest.new(@server)
  end
  
  #
  # Env.controllers test
  #
  
  def test_server_defines_controllers_manifest
    assert server.env.respond_to?(:controllers)
    assert server.env.controllers.kind_of?(Tap::Support::Manifest)
  end
  
  def test_controllers_manifests_detects_controllers_under_controllers_dir
    method_root.prepare(:controllers, 'sample_controller.rb') do |file| 
      file << %q{class SampleController; end}
    end
    
    controllers = server.env.controllers
    controllers.build
    entries = controllers.entries.collect {|const| const.name }
    assert_equal ["SampleController"], entries
  end
  
  def test_controllers_manifests_searches_by_key_prior_to__controller
    method_root.prepare(:controllers, 'sample_controller.rb') do |file| 
      file << %q{class SampleController; end}
    end
    
    assert_equal "SampleController", server.env.controllers.search('sample').name
  end
  
  def test_controllers_does_not_detect_nested_controllers
    method_root.prepare(:controllers, 'nested/sample_controller.rb') do |file| 
      file << %q{
      module Nested
        class SampleController; end
      end}
    end
    
    controllers = server.env.controllers
    controllers.build
    assert controllers.entries.empty?
  end
  
  #
  # initialize test
  #
  
  def test_initialize_sets_env_to_pwd
    server = Tap::Server.new
    assert_equal Dir.pwd, server.env.root.root
  end
  
  #
  # development? test
  #
  
  def test_development_is_true_if_environment_is_development
    assert_equal :development, server.environment
    assert server.development?
    
    server.environment = :production
    assert !server.development?
  end
  
  #
  # call tests
  #
  
  class RegisteredController
    def initialize(body)
      @body = body
    end
    def call(env)
      [200, {}, @body]
    end
  end
  
  def test_call_routes_to_registered_controller
    server.controllers['route'] = RegisteredController.new("result")
    assert_equal "result", request.get('/route').body
  end
  
  class AdjustController
    def self.call(env)
      headers = {'script_name' => env['SCRIPT_NAME'], 'path_info' => env['PATH_INFO']}
      [200, headers, ""]
    end
  end

  def test_call_adjusts_env_to_reflect_reroute
    server.controllers['route'] = AdjustController
    
    headers = request.get("/route").headers
    assert_equal "/route", headers['script_name']
    assert_equal "/", headers['path_info']
    
    headers = request.get("/route/path").headers
    assert_equal "/route", headers['script_name']
    assert_equal "/path", headers['path_info']
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    server.controllers['action'] = AdjustController
    
    headers = request.get("/%61ction/a%2Bb/c%20d")
    assert_equal "/%61ction", headers['script_name']
    assert_equal "/a%2Bb/c%20d", headers['path_info']
  end
  
  class EnvController
    def self.call(env)
      [200, {}, env['tap.server'].object_id.to_s]
    end
  end

  def test_call_adds_server_to_env
    server.controllers['route'] = EnvController
    assert_equal server.object_id.to_s, request.get("/route").body
  end
  
  class RouteController
    def self.call(env)
      [200, {}, to_s]
    end
  end
  
  def test_call_routes_to_env_controllers
    method_root.prepare(:controllers, 'sample_route_controller.rb') do |file| 
      file << %q{class SampleRouteController < ServerTest::RouteController; end}
    end
  
    assert_equal "SampleRouteController", request.get('/sample_route').body
    assert_equal "SampleRouteController", request.get('/sample_route/page').body
  end
  
  def test_call_routes_using_env_controller_aliases
    method_root.prepare(:controllers, 'sample_alias_controller.rb') do |file| 
      file << %q{class SampleAliasController < ServerTest::RouteController; end}
    end
  
    server.controllers['alias'] = 'sample_alias'
    assert_equal "SampleAliasController", request.get('/alias').body
    assert_equal "SampleAliasController", request.get('/alias/page').body
  end
  
  def test_call_routes_unknown_to_app_env_controller
    method_root.prepare(:controllers, 'app_controller.rb') do |file| 
      file << %q{class AppController < ServerTest::RouteController; end}
    end
    
    assert_equal "AppController", request.get('/').body
    assert_equal "AppController", request.get('/unknown').body
    assert_equal "AppController", request.get('/app').body
    assert_equal "AppController", request.get('/app/page').body
  end
  
  class ErrorController
    attr_accessor :err
    def initialize(err)
      @err = err
    end
    def call(env)
      raise err
    end
  end

  def test_call_returns_500_for_unhandled_error
    err = Exception.new "message"
    server.controllers['err'] = ErrorController.new(err)
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}", res.body
  end
  
  def test_call_returns_response_for_ServerErrors
    err = Tap::ServerError.new("msg")
    server.controllers['err'] = ErrorController.new(err)
  
    res = request.get('/err')
    assert_equal 500, res.status
    assert_equal({'Content-Type' => 'text/plain'}, res.headers)
    assert_equal "msg", res.body
  end
  
  def test_call_returns_404_when_no_controller_can_be_found
    res = request.get('/unknown')
    assert_equal 404, res.status
    assert_equal "404 Error: could not route to controller", res.body
  end
  
  #
  # benchmark test
  #
  
  class BenchmarkController
    def self.call(env)
      [200, {}, env['PATH_INFO']]
    end
  end

  def test_call_speed
    benchmark_test(20) do |x|
      server.controllers['route'] = BenchmarkController
      n = 10*1000
      
      env = Rack::MockRequest.env_for("/route")
      x.report("10k call") { n.times { BenchmarkController.call(env.dup) } }
      assert_equal [200, {}, "/"], server.call(env)
      
      env = Rack::MockRequest.env_for("/route")
      x.report("10k route") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, "/"], server.call(env)
      
      env = Rack::MockRequest.env_for("/route/to/resource")
      x.report("10k route/path") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, "/to/resource"], server.call(env)
      
      method_root.prepare(:controllers, 'bench_controller.rb') do |file| 
        file << %q{class BenchController < ServerTest::BenchmarkController; end}
      end
      
      env = Rack::MockRequest.env_for("/bench")
      x.report("1k dev env") { 1000.times { server.call(env.dup) } }
      assert_equal [200, {}, "/"], server.call(env)
      
      server.environment = :production
      env = Rack::MockRequest.env_for("/bench")
      x.report("10k pro env") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, "/"], server.call(env)
    end
  end
end
