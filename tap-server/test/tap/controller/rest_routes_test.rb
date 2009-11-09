require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controller'

class RestRoutesTest < Test::Unit::TestCase
  acts_as_file_test
  
  #
  # rest routes test
  #
  
  class RestfulController < Tap::Controller
    include RestRoutes
    
    def index
      "index"
    end
    
    def show(id)
      "show #{id}"
    end
    
    def edit(id)
      "edit #{id}"
    end
    
    def create(id)
      "create #{id}"
    end
    
    def update(id)
      "update #{id}"
    end
    
    def destroy(id)
      "destroy #{id}"
    end
    
    def another(id)
      "another #{id}"
    end
  end
  
  def test_rest_routes
    controller = RestfulController.new
    request = Rack::MockRequest.new controller
    
    assert_equal "index", request.get("/").body
    assert_equal "show 1", request.get("/1").body
    assert_equal "create 1", request.post("/1").body
    assert_equal "update 1", request.put("/1").body
    assert_equal "update 1", request.post("/1?_method=put").body
    assert_equal "destroy 1", request.delete("/1").body
    assert_equal "destroy 1", request.post("/1?_method=delete").body
    assert_equal "another 1", request.post("/1?_method=another").body
  end
  
  def test_rest_routing_raises_error_for_unknown_post_method
    env = Rack::MockRequest.env_for("/1?_method=unknown", 'REQUEST_METHOD' => 'POST')
    controller = RestfulController.new
    
    e = assert_raises(Tap::Server::ServerError) { controller.call(env) }
    assert_equal "unknown post method: unknown", e.message
  end
  
  def test_rest_routing_raises_error_for_unknown_request_method
    env = Rack::MockRequest.env_for("/", 'REQUEST_METHOD' => 'UNKNOWN')
    controller = RestfulController.new
    
    e = assert_raises(Tap::Server::ServerError) { controller.call(env) }
    assert_equal "unknown request method: UNKNOWN", e.message
  end
  
  class DataController < Tap::Controller
    include RestRoutes

    def index
      server.data.index(:tmp).join(", ")
    end
    
    def show(id)
      server.data.read(:tmp, id) || ""
    end
    
    def create(id)
      server.data.create(:tmp, id) {|io| io << "create" }
    end
    
    def update(id)
      server.data.update(:tmp, id) {|io| io << "update" }
    end
    
    def destroy(id)
      server.data.destroy(:tmp, id).to_s
    end
  end
  
  def test_a_sample_data_controller
    server = Tap::Server.new(:data => Tap::Server::Data.new(method_root)) do |env|
      DataController.call(env)
    end
    
    request = Rack::MockRequest.new server
    
    assert_equal "", request.get("/").body
    assert_equal "", request.get("/1").body
    
    # create
    path = method_root.path(:tmp, "1")
    assert_equal path, request.post("/1").body
    assert_equal "create", File.read(path)
    
    assert_equal "1", request.get("/").body
    assert_equal "create", request.get("/1").body
    
    # update
    assert_equal path, request.put("/1").body
    assert_equal "update", File.read(path)
    
    assert_equal "1", request.get("/").body
    assert_equal "update", request.get("/1").body
    
    # destroy
    assert_equal "true", request.delete("/1").body
    assert !File.exists?(path)
    
    assert_equal "", request.get("/").body
    assert_equal "", request.get("/1").body
  end
end